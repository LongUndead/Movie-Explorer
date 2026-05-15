const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
require('dotenv').config();
const axios = require('axios');

const app = express();
app.use(express.json());
app.use(cors());
// ==========================================
// 1. KẾT NỐI DATABASE (Đã cập nhật SSL cho Aiven)
// ==========================================
// const db = mysql.createConnection({
//     host: process.env.DB_HOST,
//     user: process.env.DB_USER,
//     password: process.env.DB_PASS,
//     database: process.env.DB_NAME,
//     port: process.env.DB_PORT || 10944, // Ưu tiên port của biến môi trường
//     ssl: {
//         rejectUnauthorized: false // Bắt buộc để kết nối được với Aiven Cloud
//     }
// });
// db.connect(err => {
//     if (err) {
//         console.error('❌ Lỗi kết nối MySQL:', err.message);
//         return;
//     }
//     console.log('✅ Đã kết nối thành công Database Aiven MySQL!');
// });

// ==========================================
// 1. KẾT NỐI DATABASE MYSQL
// ==========================================
// TỐI ƯU 1: THAY VÌ DÙNG createConnection, HÃY DÙNG createPool
const db = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT || 3306,
    waitForConnections: true,
    connectionLimit: 10, // Luôn giữ sẵn 10 kết nối túc trực
    queueLimit: 0
});

// Chạy thử 1 query để test lúc khởi động
db.query("SELECT 1", (err) => {
    if (err) console.error('❌ Lỗi Pool MySQL:', err.message);
    else console.log('✅ Đã kết nối thành công Database bằng Pool!');
});

// ==========================================
// 2. CÁC API TỰ ĐỘNG (TOOL)
// ==========================================

// Hàm hỗ trợ tạo ngày giờ chiếu ngẫu nhiên
function getRandomShowtime(daysAhead) {
    const date = new Date();
    date.setDate(date.getDate() + Math.floor(Math.random() * daysAhead));
    
    const randomHour = Math.floor(Math.random() * (22 - 8 + 1)) + 8;
    const randomMinute = Math.random() < 0.5 ? '00' : '30'; 
    
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hour = String(randomHour).padStart(2, '0');

    return `${year}-${month}-${day} ${hour}:${randomMinute}:00`;
}

// API TỰ ĐỘNG TẠO SUẤT CHIẾU VÀ GHẾ
app.get('/api/auto-setup', async (req, res) => {
    try {
        // =========================================================
        // 1. XÓA SẠCH RÁC: LỊCH CHIẾU, GHẾ LỖI, VÀ RẠP TỪ 2->5
        // =========================================================
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 0");
        await db.promise().query("TRUNCATE TABLE showtimes");
        await db.promise().query("TRUNCATE TABLE seats"); // <--- Quét sạch ghế cũ!
        await db.promise().query("DELETE FROM rooms WHERE Name LIKE '%Rạp 2%' OR Name LIKE '%Rạp 3%' OR Name LIKE '%Rạp 4%' OR Name LIKE '%Rạp 5%'");
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 1");

        // Hàm định nghĩa sức chứa chuẩn không cần chỉnh
        const getExactCapacity = (cinemaName) => {
            const name = cinemaName.toLowerCase();
            if (name.includes('cgv')) return 182;
            if (name.includes('lotte')) return 230;
            if (name.includes('galaxy')) return 220;
            if (name.includes('bhd')) return 219;
            if (name.includes('cinestar')) return 200;
            if (name.includes('mega gs') || name.includes('megags')) return 210;
            return 150; 
        };

        // =========================================================
        // 2. CƯỠNG CHẾ SỬA TẤT CẢ CÁC RẠP CŨ THÀNH SỐ GHẾ CHUẨN
        // =========================================================
        const [existingRooms] = await db.promise().query("SELECT RoomID, Name FROM rooms");
        for (const room of existingRooms) {
            const exactCapacity = getExactCapacity(room.Name);
            // Lệnh này sẽ đè bẹp mọi con số 150 thành 182, 230...
            await db.promise().query("UPDATE rooms SET TotalSeats = ? WHERE RoomID = ?", [exactCapacity, room.RoomID]);
        }

        // =========================================================
        // 3. NHÂN BẢN CHO ĐỦ 5 PHÒNG MỖI RẠP
        // =========================================================
        const [cinemas] = await db.promise().query("SELECT id, name FROM cinemas");
        const [roomCounts] = await db.promise().query("SELECT CinemaID, COUNT(*) as count FROM rooms GROUP BY CinemaID");
        
        const roomCountMap = {};
        roomCounts.forEach(r => roomCountMap[r.CinemaID] = r.count);

        const newRooms = [];
        cinemas.forEach(cinema => {
            const currentRooms = roomCountMap[cinema.id] || 0;
            const targetRooms = 5; 
            const exactCapacity = getExactCapacity(cinema.name); 
            
            for (let i = currentRooms + 1; i <= targetRooms; i++) {
                newRooms.push([cinema.id, `${cinema.name} - Rạp ${i}`, exactCapacity, 10]);
            }
        });

        if (newRooms.length > 0) {
            await db.promise().query("INSERT INTO rooms (CinemaID, Name, TotalSeats, BufferMinutes) VALUES ?", [newRooms]);
        }

        // =========================================================
        // 4. RẢI SUẤT CHIẾU DÀY ĐẶC (ROUND-ROBIN)
        // =========================================================
        const [movies] = await db.promise().query("SELECT id, COALESCE(duration, 120) as duration FROM movies");
        const [allRoomsFinal] = await db.promise().query("SELECT RoomID, COALESCE(BufferMinutes, 10) as buffer FROM rooms");

        if (movies.length === 0) return res.status(400).json({ error: "Vui lòng chạy sync-movies trước!" });

        const showtimeValues = [];
        const daysToSchedule = 7; 
        const now = new Date();
        let movieIndex = 0; 

        for (let dayOffset = 0; dayOffset < daysToSchedule; dayOffset++) {
            for (const room of allRoomsFinal) {
                let currentStartTime = new Date(now);
                currentStartTime.setDate(now.getDate() + dayOffset);
                currentStartTime.setHours(8, 30, 0, 0); 

                const endTimeLimit = new Date(currentStartTime);
                endTimeLimit.setHours(23, 0, 0, 0); 

                while (currentStartTime < endTimeLimit) {
                    const currentMovie = movies[movieIndex % movies.length];
                    movieIndex++; 

                    const isCinetour = Math.random() < 0.1 ? 1 : 0; 
                    const pad = (n) => (n < 10 ? '0' + n : n);
                    const formattedStartTime = `${currentStartTime.getFullYear()}-${pad(currentStartTime.getMonth() + 1)}-${pad(currentStartTime.getDate())} ${pad(currentStartTime.getHours())}:${pad(currentStartTime.getMinutes())}:00`;

                    showtimeValues.push([currentMovie.id, room.RoomID, formattedStartTime, 95000, isCinetour]);

                    const totalMinutesToAdd = currentMovie.duration + room.buffer + 10; 
                    currentStartTime.setMinutes(currentStartTime.getMinutes() + totalMinutesToAdd);
                }
            }
        }

        if (showtimeValues.length > 0) {
            await db.promise().query("INSERT INTO showtimes (MovieID, RoomID, StartTime, Price, cinetour) VALUES ?", [showtimeValues]);
        }

        // =========================================================
        // 5. NHÀ MÁY ĐÚC GHẾ TOÁN HỌC (Sinh ra hơn 15.000 ghế chuẩn)
        // =========================================================
        const [roomsToSeat] = await db.promise().query("SELECT RoomID, TotalSeats FROM rooms");
        let totalSeatsInserted = 0;

        for (const room of roomsToSeat) {
            const capacity = room.TotalSeats; 
            const seatValues = [];
            const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
            const seatsPerRow = capacity >= 200 ? 16 : 14; 
            let count = 0;

            for (let r = 0; r < 26; r++) {
                for (let c = 1; c <= seatsPerRow; c++) {
                    if (count >= capacity) break;
                    seatValues.push([room.RoomID, `${letters[r]}${c}`, 1]);
                    count++;
                }
                if (count >= capacity) break;
            }

            if (seatValues.length > 0) {
                await db.promise().query("INSERT INTO seats (RoomID, SeatNumber, SeatTypeID) VALUES ?", [seatValues]);
                totalSeatsInserted += seatValues.length;
            }
        }

        res.json({ 
            success: true, 
            message: `🔥 ĐÃ CƯỠNG CHẾ THÀNH CÔNG: Quét sạch số 150 lỗi! Tự động đúc chuẩn xác ${totalSeatsInserted} ghế (CGV 182, Lotte 230...). Đã tạo ${showtimeValues.length} suất chiếu!` 
        });
    } catch (error) {
        console.error("Lỗi auto-setup:", error);
        res.status(500).json({ error: error.message });
    }
});
// API: DỌN DẸP RÁC (Xóa suất chiếu và vé cũ trước ngày hôm nay)
app.get('/api/clean-up', async (req, res) => {
    try {
        // 1. Xóa chi tiết ghế đã đặt của các suất chiếu cũ
        await db.promise().query(`
            DELETE bs FROM bookingseats bs 
            JOIN bookings b ON bs.BookingID = b.BookingID 
            JOIN showtimes s ON b.ShowtimeID = s.ShowtimeID 
            WHERE s.StartTime < NOW()
        `);

        // 2. Xóa các hóa đơn booking của suất chiếu cũ
        await db.promise().query(`
            DELETE b FROM bookings b 
            JOIN showtimes s ON b.ShowtimeID = s.ShowtimeID 
            WHERE s.StartTime < NOW()
        `);

        // 3. Xóa trạng thái ghế (seatstatus - nếu có) của suất chiếu cũ
        await db.promise().query(`
            DELETE ss FROM seatstatus ss 
            JOIN showtimes s ON ss.ShowtimeID = s.ShowtimeID 
            WHERE s.StartTime < NOW()
        `);

        // 4. Cuối cùng, tiêu diệt các suất chiếu đã hết hạn
        const [result] = await db.promise().query(`
            DELETE FROM showtimes WHERE StartTime < NOW()
        `);

        res.json({ 
            success: true, 
            message: `🧹 Đã dọn dẹp sạch sẽ! Xóa thành công ${result.affectedRows} suất chiếu cũ và các dữ liệu rác liên quan.` 
        });
    } catch (error) {
        console.error("Lỗi dọn dẹp:", error);
        res.status(500).json({ error: error.message });
    }
});

// API CÀO PHIM TỪ TMDB
// ==========================================================
// API ĐỒNG BỘ PHIM (CÓ ĐANG CHIẾU, SẮP CHIẾU & PHIM VIỆT)
// ==========================================================
app.get('/api/sync-movies', async (req, res) => {
    const TMDB_API_KEY = '1f555345923a2d2034eae91200dfb80e'; 
    
    // ==========================================
    // KHU VỰC CÀI ĐẶT
    // ==========================================
    const pagesToFetch = 2; // Số trang cho mỗi loại (2 trang = 40 phim/loại)
    const fromDate = '2025-01-01'; // Lấy phim từ năm 2025 trở lại đây cho mới
    const today = new Date().toISOString().slice(0, 10); // Ngày hôm nay (YYYY-MM-DD)
    
    let totalSynced = 0;

    try {
        // 1. Lấy danh sách thể loại từ TMDB để map ID sang Tên
        const genreRes = await axios.get(`https://api.themoviedb.org/3/genre/movie/list?api_key=${TMDB_API_KEY}&language=vi-VN`);
        const genreMap = {};
        genreRes.data.genres.forEach(g => genreMap[g.id] = g.name);

        // 2. Tự động sinh ra danh sách link quét đa dạng
        const fetchUrls = [];
        
        // Nhóm 1: Phim ĐANG CHIẾU Toàn Cầu (Ra mắt <= Hôm nay)
        for (let page = 1; page <= pagesToFetch; page++) {
            fetchUrls.push(`https://api.themoviedb.org/3/discover/movie?api_key=${TMDB_API_KEY}&language=vi-VN&primary_release_date.gte=${fromDate}&primary_release_date.lte=${today}&sort_by=popularity.desc&page=${page}`);
        }

        // Nhóm 2: Phim SẮP CHIẾU Toàn Cầu (Ra mắt > Hôm nay)
        for (let page = 1; page <= pagesToFetch; page++) {
            fetchUrls.push(`https://api.themoviedb.org/3/discover/movie?api_key=${TMDB_API_KEY}&language=vi-VN&primary_release_date.gt=${today}&sort_by=popularity.desc&page=${page}`);
        }

        // Nhóm 3: Phim VIỆT NAM (Lấy cả Đang chiếu & Sắp chiếu)
        fetchUrls.push(`https://api.themoviedb.org/3/discover/movie?api_key=${TMDB_API_KEY}&language=vi-VN&with_original_language=vi&primary_release_date.gte=${fromDate}&sort_by=popularity.desc&page=1`);

        // 3. Tiến hành lặp qua các đường link và hốt phim
        for (const targetUrl of fetchUrls) {
            const response = await axios.get(targetUrl);
            const movies = response.data.results;

            for (const m of movies) {
                try {
                    // Gọi chi tiết để lấy Trailer, Ảnh và Thời lượng
                    const detailRes = await axios.get(
                        `https://api.themoviedb.org/3/movie/${m.id}?api_key=${TMDB_API_KEY}&append_to_response=release_dates,credits,videos,images&include_image_language=vi,en,null&include_video_language=vi,en&language=vi-VN`
                    );
                    const details = detailRes.data;

                    // --- BÓC TÁCH DỮ LIỆU ---

                    // A. Trailer YouTube
                    const trailer = details.videos?.results?.find(v => v.type === 'Trailer' && v.site === 'YouTube');
                    const trailerUrl = trailer ? `https://www.youtube.com/watch?v=${trailer.key}` : null;

                    // B. Thời lượng (Runtime)
                    const runtime = (details.runtime && details.runtime > 0) ? details.runtime : 120;

                    // C. Bộ sưu tập ảnh ngang (Tối đa 5 ảnh)
                    let galleryImages = [];
                    if (details.images && details.images.backdrops && details.images.backdrops.length > 0) {
                        galleryImages = details.images.backdrops.slice(0, 5).map(img => img.file_path);
                    } else if (m.backdrop_path) {
                        galleryImages.push(m.backdrop_path);
                    }
                    const backdropJson = JSON.stringify(galleryImages);

                    // D. Xử lý chuẩn Độ tuổi (VN và US)
                    let ageRating = 'P'; 
                    if (details.release_dates && details.release_dates.results) {
                        const vnRelease = details.release_dates.results.find(r => r.iso_3166_1 === 'VN');
                        if (vnRelease) {
                            const validCert = vnRelease.release_dates.find(d => d.certification && d.certification.trim() !== '');
                            if (validCert) ageRating = validCert.certification;
                        }
                        // Nếu VN không có, lấy US và dịch sang VN
                        if (ageRating === 'P' || ageRating === '') {
                            const usRelease = details.release_dates.results.find(r => r.iso_3166_1 === 'US');
                            if (usRelease) {
                                const validCert = usRelease.release_dates.find(d => d.certification && d.certification.trim() !== '');
                                if (validCert) {
                                    const usCert = validCert.certification;
                                    if (['G'].includes(usCert)) ageRating = 'P';
                                    else if (['PG'].includes(usCert)) ageRating = 'K';
                                    else if (['PG-13'].includes(usCert)) ageRating = 'T13';
                                    else if (['R', 'NC-17'].includes(usCert)) ageRating = 'T18';
                                    else ageRating = usCert;
                                }
                            }
                        }
                    }
                    if (!ageRating || ageRating.trim() === '') ageRating = 'P';

                    // E. Ngôn ngữ
                    let lang = details.original_language === 'en' ? 'Tiếng Anh' : 
                               (details.original_language === 'ko' ? 'Tiếng Hàn' : 
                               (details.original_language === 'ja' ? 'Tiếng Nhật' : 
                               (details.original_language === 'vi' ? 'Tiếng Việt' : 'Phụ đề')));

                    let releaseDate = m.release_date;
                    if (!releaseDate || releaseDate.trim() === '') releaseDate = null;

                    // F. Chuỗi Diễn viên và Thể loại cho bảng movies
                    const genresStr = m.genre_ids ? m.genre_ids.map(id => genreMap[id]).join(', ') : 'Phim chiếu rạp';
                    const castData = details.credits?.cast?.slice(0, 5).map(actor => ({
                        name: actor.name,
                        character: actor.character,
                        profile_path: actor.profile_path
                    })) || [];
                    const castJson = JSON.stringify(castData);

                    // ==========================================
                    // LƯU VÀO BẢNG CHÍNH: movies
                    // ==========================================
                    const movieSql = `INSERT INTO movies 
                        (id, title, poster_path, backdrop_path, duration, overview, release_date, vote_average, genres, age_rating, language, cast, TrailerURL) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) 
                        ON DUPLICATE KEY UPDATE 
                        backdrop_path=VALUES(backdrop_path), duration=VALUES(duration), 
                        overview=VALUES(overview), release_date=VALUES(release_date), 
                        vote_average=VALUES(vote_average), genres=VALUES(genres), 
                        age_rating=VALUES(age_rating), language=VALUES(language), 
                        cast=VALUES(cast), TrailerURL=VALUES(TrailerURL)`;
                    
                    const movieValues = [
                        m.id, m.title, m.poster_path, backdropJson, 
                        runtime, m.overview || 'Đang cập nhật...', 
                        releaseDate, m.vote_average || 0, genresStr, ageRating, lang, 
                        castJson, trailerUrl 
                    ];
                    await db.promise().query(movieSql, movieValues);

                    // ==========================================
                    // LƯU VÀO BẢNG PHỤ 3NF (Khớp cấu trúc SQL Dump)
                    // ==========================================
                    if (m.genre_ids && m.genre_ids.length > 0) {
                        for (const gId of m.genre_ids) {
                            const gName = genreMap[gId] || 'Khác';
                            await db.promise().query(`INSERT IGNORE INTO genres (GenreID, GenreName) VALUES (?, ?)`, [gId, gName]);
                            await db.promise().query(`INSERT IGNORE INTO moviegenres (MovieID, GenreID) VALUES (?, ?)`, [m.id, gId]);
                        }
                    }
                    if (details.credits && details.credits.cast) {
                        for (const actor of castData) {
                            // Mảng castData ở trên lưu name, character, profile_path
                            // Sửa lại chỗ lấy ActorID từ detail gốc
                            const originalActor = details.credits.cast.find(a => a.name === actor.name);
                            if (originalActor) {
                                await db.promise().query(`INSERT IGNORE INTO actors (ActorID, Name, Avatar) VALUES (?, ?, ?)`, [originalActor.id, originalActor.name, originalActor.profile_path]);
                                await db.promise().query(`INSERT IGNORE INTO movieactors (MovieID, ActorID, CharacterName) VALUES (?, ?, ?)`, [m.id, originalActor.id, originalActor.character]);
                            }
                        }
                    }

                    totalSynced++;
                } catch (err) {
                    console.log(`❌ Lỗi tại phim ${m.id} (${m.title}):`, err.message);
                }
                // Nghỉ 50ms giữa các lần cào để không bị chặn IP
                await new Promise(resolve => setTimeout(resolve, 50)); 
            }
        }

        res.json({ success: true, message: `🚀 Đã "hốt" trọn vẹn ${totalSynced} phim (Có Đang Chiếu, Sắp Chiếu & Phim VN)!` });
    } catch (error) {
        console.error("❌ Lỗi Tổng:", error);
        res.status(500).json({ error: error.message });
    }
});
// API: Quét sạch bảng phim để nạp lại từ đầu
app.get('/api/clear-all-movies', async (req, res) => {
    try {
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 0");
        await db.promise().query("TRUNCATE TABLE movies");
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 1");
        
        res.json({ success: true, message: "🗑️ Đã quét sạch bảng phim! Bây giờ bạn hãy chạy api/sync-movies để nạp dữ liệu mới." });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// 3. CÁC API LẤY DỮ LIỆU (GET) - CHO FLUTTER APP
// ==========================================

// Lấy danh sách phim
app.get('/api/movies', (req, res) => {
    db.query("SELECT * FROM movies", (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

// Lấy danh sách Rạp
app.get('/api/cinemas', async (req, res) => {
    try {
        const brand = req.query.brand; 
        const isRandom = req.query.random; // Công tắc lấy rạp ngẫu nhiên

        let sql = '';
        let params = [];

        // Trường hợp 1: Bật công tắc random -> Lấy 3 rạp điểm cao cho Trang Chủ
        if (isRandom === 'true') {
            sql = 'SELECT * FROM cinemas WHERE rating >= 4.5 AND IsDeleted = 0 ORDER BY RAND() LIMIT 3';
        } 
        // Trường hợp 2: Có gửi tên brand -> Lấy đúng cụm rạp đó (VD: Chỉ lấy CGV)
        else if (brand && brand.trim() !== '') {
            sql = 'SELECT * FROM cinemas WHERE brand = ? AND IsDeleted = 0';
            params = [brand.trim()];
        } 
        // Trường hợp 3: Không gửi gì cả -> LẤY TẤT CẢ DANH SÁCH RẠP
        else {
            sql = 'SELECT * FROM cinemas WHERE IsDeleted = 0';
        }

        const [results] = await db.promise().query(sql, params);
        
        res.json(results);
        
    } catch (error) {
        console.error("❌ Lỗi API /api/cinemas:", error);
        res.status(500).json({ error: 'Lỗi Database: ' + error.message });
    }
});

// Lấy lịch chiếu của 1 bộ phim theo rạp & ngày
app.get('/api/showtimes', (req, res) => {
    const movieId = req.query.movie_id;
    const cinemaId = req.query.cinema_id;
    const date = req.query.date; // Bắt buộc định dạng: YYYY-MM-DD

    if (!movieId || !cinemaId || !date) {
        return res.status(400).json({ error: "Thiếu tham số (movie_id, cinema_id, date)!" });
    }

    const sql = `
        SELECT 
            s.ShowtimeID, 
            s.StartTime, 
            s.EndTime, 
            s.Price, 
            s.cinetour AS IsCinetour,
            r.Name AS RoomName,
            r.TotalSeats, 
            (r.TotalSeats - (
                SELECT COUNT(bs.SeatID) 
                FROM bookingseats bs 
                JOIN bookings b ON bs.BookingID = b.BookingID 
                WHERE b.ShowtimeID = s.ShowtimeID AND bs.Status = 'Booked'
            )) AS AvailableSeats
        FROM showtimes s
        JOIN rooms r ON s.RoomID = r.RoomID
        WHERE s.MovieID = ? AND r.CinemaID = ? AND DATE(s.StartTime) = ?
        ORDER BY s.StartTime ASC
    `;

    db.query(sql, [movieId, cinemaId, date], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});
// ===================================================================
// 2. API DÀNH RIÊNG CHO ĐỔI SUẤT CHIẾU (Lấy TẤT CẢ rạp, KHÔNG cần cinema_id)
// ===================================================================
// ===================================================================
// 2. API DÀNH RIÊNG CHO ĐỔI SUẤT CHIẾU (Lấy TẤT CẢ rạp)
// ===================================================================
app.get('/api/showtimes-all', (req, res) => {
    const movieId = req.query.movie_id;
    const date = req.query.date;

    if (!movieId || !date) {
        return res.status(400).json({ error: "Thiếu tham số (movie_id, date)!" });
    }

    const sql = `
        SELECT 
            s.ShowtimeID, s.StartTime, s.EndTime, s.Price, s.cinetour AS IsCinetour,
            r.Name AS RoomName, 
            c.Name AS cinema_name, 
            r.TotalSeats, 
            (r.TotalSeats - (
                SELECT COUNT(bs.SeatID) FROM bookingseats bs 
                JOIN bookings b ON bs.BookingID = b.BookingID 
                WHERE b.ShowtimeID = s.ShowtimeID AND bs.Status = 'Booked'
            )) AS AvailableSeats
        FROM showtimes s
        JOIN rooms r ON s.RoomID = r.RoomID
        
        /* ✅ ĐÃ SỬA c.CinemaID THÀNH c.id */
        JOIN cinemas c ON r.CinemaID = c.id 
        
        WHERE s.MovieID = ? AND DATE(s.StartTime) = ?
        ORDER BY s.StartTime ASC
    `;

    db.query(sql, [movieId, date], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

// Lấy sơ đồ ghế ngồi của 1 suất chiếu
// Lấy sơ đồ ghế ngồi của 1 suất chiếu (Đã fix lỗi SeatTypeID)
app.get('/api/seats/:showtimeId', (req, res) => {
    const showtimeId = req.params.showtimeId;
    const sql = `
        SELECT s.SeatID, s.SeatNumber, 
               stype.TypeName AS SeatType,
               CASE WHEN bs.BookingSeatID IS NOT NULL THEN 'Occupied' ELSE 'Available' END AS status
        FROM seats s
        JOIN showtimes st ON s.RoomID = st.RoomID
        JOIN seattypes stype ON s.SeatTypeID = stype.SeatTypeID
        LEFT JOIN bookings b ON b.ShowtimeID = st.ShowtimeID AND b.Status = 'Paid'
        LEFT JOIN bookingseats bs ON bs.SeatID = s.SeatID AND bs.BookingID = b.BookingID AND bs.Status = 'Booked'
        WHERE st.ShowtimeID = ?
    `;
    db.query(sql, [showtimeId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});


// ==========================================
// 4. API NGHIỆP VỤ (POST)
// ==========================================

// API Đăng nhập
app.post('/api/login', (req, res) => {
    const { email, password } = req.body;
    
    // Đã đổi cột khớp với bảng users của bạn
    const sql = "SELECT UserID, Username, Email, Phone, Avatar FROM users WHERE Email = ? AND PasswordHash = ?";
    
    db.query(sql, [email, password], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.length > 0) {
            res.json({ message: "Đăng nhập thành công", user: results[0] });
        } else {
            res.status(401).json({ error: "Sai email hoặc mật khẩu" });
        }
    });
});

// API Đặt vé (Dùng Transaction để đảm bảo an toàn)
// API Đặt vé (Đã fix lỗi Pool Transaction và thêm ShowtimeID chống Double Booking)
app.post('/api/book-tickets', (req, res) => {
    const { userId, showtimeId, seatIds, totalPrice } = req.body;

    if (!seatIds || seatIds.length === 0) {
        return res.status(400).json({ error: "Chưa chọn ghế!" });
    }

    // Pool MySQL bắt buộc phải getConnection trước khi transaction
    db.getConnection((err, connection) => {
        if (err) return res.status(500).json({ error: "Lỗi kết nối database" });

        connection.beginTransaction((err) => {
            if (err) return connection.release();

            // 1. Tạo đơn hóa đơn
            const bookingSql = "INSERT INTO bookings (UserID, ShowtimeID, TotalAmount, Status) VALUES (?, ?, ?, 'Paid')";
            connection.query(bookingSql, [userId, showtimeId, totalPrice], (err, bookingResult) => {
                if (err) {
                    return connection.rollback(() => {
                        connection.release();
                        res.status(500).json({ error: "Lỗi tạo hóa đơn" });
                    });
                }

                const bookingId = bookingResult.insertId;
                const pricePerSeat = totalPrice / seatIds.length;
                
                // 2. Chèn từng ghế (Bổ sung ShowtimeID để CSDL không báo lỗi UNIQUE)
                const bookingSeatValues = seatIds.map(seatId => [bookingId, showtimeId, seatId, pricePerSeat, 'Booked']);
                const seatSql = "INSERT INTO bookingseats (BookingID, ShowtimeID, SeatID, Price, Status) VALUES ?";

                connection.query(seatSql, [bookingSeatValues], (err) => {
                    if (err) {
                        return connection.rollback(() => {
                            connection.release();
                            res.status(400).json({ error: "Thất bại: Ghế đã có người đặt trước!" });
                        });
                    }

                    // 3. Chốt giao dịch
                    connection.commit((err) => {
                        if (err) {
                            return connection.rollback(() => {
                                connection.release();
                                res.status(500).json({ error: "Lỗi xác nhận" });
                            });
                        }
                        connection.release();
                        res.json({ message: "🎉 Đặt vé thành công!", bookingId: bookingId });
                    });
                });
            });
        });
    });
});

// ==========================================
// 5. KHỞI ĐỘNG SERVER
// ==========================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server backend đang chạy tại port: ${PORT}`);
});