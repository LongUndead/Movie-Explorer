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
        const [movies] = await db.promise().query("SELECT id FROM movies");
        const [rooms] = await db.promise().query("SELECT RoomID FROM rooms");

        if (movies.length === 0 || rooms.length === 0) {
            return res.status(400).json({ error: "Vui lòng chạy sync-movies và tạo Room trước!" });
        }

        const showtimeValues = [];
        movies.forEach(movie => {
            rooms.forEach(room => {
                const isCinetour = Math.random() < 0.2 ? 1 : 0; 
                const randomStartTime = getRandomShowtime(3);
                showtimeValues.push([movie.id, room.RoomID, randomStartTime, 95000, isCinetour]);
            });
        });

        // Chèn suất chiếu
        const stSql = "INSERT IGNORE INTO showtimes (MovieID, RoomID, StartTime, Price, cinetour) VALUES ?";
        await db.promise().query(stSql, [showtimeValues]);

        // Tạo Ghế ngồi cho mỗi phòng
        for (const room of rooms) {
            const [existingSeats] = await db.promise().query("SELECT SeatID FROM seats WHERE RoomID = ?", [room.RoomID]);
            if (existingSeats.length === 0) {
                const seatValues = [];
                for (let i = 1; i <= 10; i++) {
                    seatValues.push([room.RoomID, `A${i}`, '1']); // Đổi 'Normal' thành '1' theo chuẩn CSDL của bạn
                }
                await db.promise().query("INSERT INTO seats (RoomID, SeatNumber, SeatType) VALUES ?", [seatValues]);
            }
        }

        res.json({ message: "✅ Đã tự động tạo Suất chiếu (có Cine Tour) và sơ đồ Ghế thành công!" });
    } catch (error) {
        console.error("Lỗi auto-setup:", error);
        res.status(500).json({ error: error.message });
    }
});

// API CÀO PHIM TỪ TMDB
app.get('/api/sync-movies', async (req, res) => {
    const TMDB_API_KEY = '1f555345923a2d2034eae91200dfb80e'; 
    const pagesToFetch = 10; 
    let totalSynced = 0;

    try {
        const genreRes = await axios.get(`https://api.themoviedb.org/3/genre/movie/list?api_key=${TMDB_API_KEY}&language=vi-VN`);
        const genreMap = {};
        genreRes.data.genres.forEach(g => genreMap[g.id] = g.name);

        for (let page = 1; page <= pagesToFetch; page++) {
            const response = await axios.get(
                `https://api.themoviedb.org/3/discover/movie?api_key=${TMDB_API_KEY}&language=vi-VN&primary_release_date.gte=2023-01-01&sort_by=primary_release_date.desc&page=${page}`  
            );
            const movies = response.data.results;

            for (const m of movies) {
                try {
                    const detailRes = await axios.get(
                        `https://api.themoviedb.org/3/movie/${m.id}?api_key=${TMDB_API_KEY}&append_to_response=release_dates,credits&language=vi-VN`
                    );
                    const details = detailRes.data;

                    let ageRating = 'P'; 
                    const releaseDates = details.release_dates?.results || [];
                    const vnRelease = releaseDates.find(r => r.iso_3166_1 === 'VN');
                    const usRelease = releaseDates.find(r => r.iso_3166_1 === 'US');
                    
                    if (vnRelease && vnRelease.release_dates[0].certification) {
                        ageRating = vnRelease.release_dates[0].certification;
                    } else if (usRelease && usRelease.release_dates[0].certification) {
                        ageRating = usRelease.release_dates[0].certification;
                    }
                    if (ageRating === '') ageRating = 'P'; 

                    let lang = details.original_language === 'en' ? 'Tiếng Anh' : 
                               (details.original_language === 'ko' ? 'Tiếng Hàn' : 
                               (details.original_language === 'ja' ? 'Tiếng Nhật' : 
                               (details.original_language === 'vi' ? 'Tiếng Việt' : 'Phụ đề')));

                    const castData = details.credits?.cast?.slice(0, 5).map(actor => ({
                        id: actor.id,
                        name: actor.name,
                        character: actor.character,
                        profile_path: actor.profile_path
                    })) || [];
                    const castJson = JSON.stringify(castData); 

                    let releaseDate = m.release_date;
                    if (!releaseDate || releaseDate.trim() === '') releaseDate = null;
                    const genresStr = m.genre_ids ? m.genre_ids.map(id => genreMap[id]).join(', ') : 'Phim chiếu rạp';

                    const sql = `INSERT INTO movies 
                        (id, title, poster_path, duration, overview, release_date, vote_average, genres, age_rating, language, cast) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) 
                        ON DUPLICATE KEY UPDATE 
                        title=VALUES(title), overview=VALUES(overview), vote_average=VALUES(vote_average), 
                        genres=VALUES(genres), release_date=VALUES(release_date), 
                        age_rating=VALUES(age_rating), language=VALUES(language), cast=VALUES(cast)`;
                    
                    const values = [
                        m.id, m.title, m.poster_path, 120, m.overview || 'Đang cập nhật...', 
                        releaseDate, m.vote_average || 0, genresStr, ageRating, lang, castJson
                    ];

                    await db.promise().query(sql, values);
                    totalSynced++;

                } catch (err) {
                    console.log(`Bỏ qua phim ${m.id} do lỗi API`);
                }
                await new Promise(resolve => setTimeout(resolve, 100)); 
            }
            console.log(`✅ Đã cào XONG CHI TIẾT trang ${page}`);
        }

        res.json({ success: true, message: `🚀 Hoàn thiện Database với ${totalSynced} phim!` });
    } catch (error) {
        console.error("Lỗi:", error);
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
app.get('/api/cinemas', (req, res) => {
    const brand = req.query.brand; 
    let sql = '';
    let params = [];

    if (!brand || brand === '') {
        sql = 'SELECT * FROM cinemas WHERE rating >= 4.5 ORDER BY RAND() LIMIT 3';
    } else {
        sql = 'SELECT * FROM cinemas WHERE brand = ?';
        params = [brand];
    }

    db.query(sql, params, (err, results) => {
        if (err) return res.status(500).json({ error: 'Lỗi Database' });
        res.json(results);
    });
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
app.get('/api/seats/:showtimeId', (req, res) => {
    const showtimeId = req.params.showtimeId;
    const sql = `
        SELECT s.SeatID, s.SeatNumber, s.SeatType,
            CASE WHEN bs.BookingSeatID IS NOT NULL THEN 'Occupied' ELSE 'Available' END AS status
        FROM seats s
        JOIN showtimes st ON s.RoomID = st.RoomID
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
app.post('/api/book-tickets', (req, res) => {
    const { userId, showtimeId, seatIds, totalPrice } = req.body;

    db.beginTransaction((err) => {
        if (err) return res.status(500).json({ error: "Lỗi giao dịch" });

        // 1. Tạo đơn trong bảng bookings thay vì orders
        const bookingSql = "INSERT INTO bookings (UserID, ShowtimeID, TotalAmount, Status) VALUES (?, ?, ?, 'Paid')";
        db.query(bookingSql, [userId, showtimeId, totalPrice], (err, bookingResult) => {
            if (err) return db.rollback(() => res.status(500).json({ error: "Lỗi tạo hóa đơn" }));

            const bookingId = bookingResult.insertId;
            const pricePerSeat = totalPrice / seatIds.length;
            
            // 2. Chèn từng ghế vào bảng bookingseats
            const bookingSeatValues = seatIds.map(seatId => [bookingId, seatId, pricePerSeat, 'Booked']);
            const seatSql = "INSERT INTO bookingseats (BookingID, SeatID, Price, Status) VALUES ?";

            db.query(seatSql, [bookingSeatValues], (err) => {
                if (err) return db.rollback(() => res.status(400).json({ error: "Ghế đã có người đặt!" }));

                db.commit((err) => {
                    if (err) return db.rollback(() => res.status(500).json({ error: "Lỗi xác nhận" }));
                    res.json({ message: "🎉 Đặt vé thành công!", bookingId: bookingId });
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