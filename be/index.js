const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(express.json());
app.use(cors());

const axios = require('axios');

// API tự động lấy phim từ TMDB và lưu vào MySQL của mình
app.get('/api/sync-movies', async (req, res) => {
    const TMDB_API_KEY = 'cfff00460e93a52bf1c3264db2d138cc'; 
    const pagesToFetch = 10; // Cào 200 phim (Vì cào sâu nên sẽ hơi lâu)
    let totalSynced = 0;

    try {
        const genreRes = await axios.get(`https://api.themoviedb.org/3/genre/movie/list?api_key=${TMDB_API_KEY}&language=vi-VN`);
        const genreMap = {};
        genreRes.data.genres.forEach(g => genreMap[g.id] = g.name);

        for (let page = 1; page <= pagesToFetch; page++) {
            const response = await axios.get(
                `https://api.themoviedb.org/3/movie/popular?api_key=${TMDB_API_KEY}&language=vi-VN&page=${page}`
            );
            const movies = response.data.results;

            // VÒNG LẶP CÀO SÂU VÀO TỪNG BỘ PHIM
            for (const m of movies) {
                try {
                    // Gọi thêm API lấy chi tiết (Credits = Diễn viên, Release_dates = Độ tuổi)
                    const detailRes = await axios.get(
                        `https://api.themoviedb.org/3/movie/${m.id}?api_key=${TMDB_API_KEY}&append_to_response=release_dates,credits&language=vi-VN`
                    );
                    const details = detailRes.data;

                    // 1. LẤY ĐỘ TUỔI (Ưu tiên chuẩn VN, không có thì lấy chuẩn US)
                    let ageRating = 'P'; // Mặc định: Phổ biến
                    const releaseDates = details.release_dates?.results || [];
                    const vnRelease = releaseDates.find(r => r.iso_3166_1 === 'VN');
                    const usRelease = releaseDates.find(r => r.iso_3166_1 === 'US');
                    
                    if (vnRelease && vnRelease.release_dates[0].certification) {
                        ageRating = vnRelease.release_dates[0].certification;
                    } else if (usRelease && usRelease.release_dates[0].certification) {
                        ageRating = usRelease.release_dates[0].certification;
                    }
                    if (ageRating === '') ageRating = 'P'; 

                    // 2. LẤY NGÔN NGỮ
                    let lang = details.original_language === 'en' ? 'Tiếng Anh' : 
                               (details.original_language === 'ko' ? 'Tiếng Hàn' : 
                               (details.original_language === 'ja' ? 'Tiếng Nhật' : 
                               (details.original_language === 'vi' ? 'Tiếng Việt' : 'Phụ đề')));

                    // 3. LẤY DIỄN VIÊN (Top 5 người đầu tiên kèm hình ảnh)
                    const castData = details.credits?.cast?.slice(0, 5).map(actor => ({
                        id: actor.id,
                        name: actor.name,
                        character: actor.character,
                        profile_path: actor.profile_path // Lấy đuôi ảnh của diễn viên
                    })) || [];
                    const castJson = JSON.stringify(castData); // Biến thành chuỗi JSON để lưu MySQL

                    // 4. XỬ LÝ DỮ LIỆU CŨ
                    let releaseDate = m.release_date;
                    if (!releaseDate || releaseDate.trim() === '') releaseDate = null;
                    const genresStr = m.genre_ids ? m.genre_ids.map(id => genreMap[id]).join(', ') : 'Phim chiếu rạp';

                    // 5. LƯU VÀO DATABASE
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
                    console.log(`Bỏ qua phim ${m.id} do lỗi API: ${err.message}`);
                }
                
                // Phanh lại 100ms giữa mỗi phim để không bị TMDB chặn
                await new Promise(resolve => setTimeout(resolve, 100)); 
            }
            console.log(`✅ Đã cào XONG CHI TIẾT trang ${page}`);
        }

        res.json({ success: true, message: `🚀 Hoàn thiện Database với ${totalSynced} phim (Kèm Diễn viên, Ngôn ngữ, Độ tuổi)!` });
    } catch (error) {
        console.error("Lỗi:", error);
        res.status(500).json({ error: error.message });
    }
});

// API TỰ ĐỘNG TẠO SUẤT CHIẾU VÀ GHẾ (Dành cho việc Demo đồ án)
app.get('/api/auto-setup', async (req, res) => {
    try {
        // 1. Lấy tất cả phim và phòng chiếu đang có
        const [movies] = await db.promise().query("SELECT id FROM movies");
        const [rooms] = await db.promise().query("SELECT id FROM rooms");

        if (movies.length === 0 || rooms.length === 0) {
            return res.status(400).json({ error: "Vui lòng chạy sync-movies và tạo Room trước!" });
        }

        // 2. Tạo Suất chiếu ngẫu nhiên cho mỗi phim (trong 3 ngày tới)
        const showtimeValues = [];
        movies.forEach(movie => {
            rooms.forEach(room => {
                // Mỗi phim ở mỗi phòng sẽ có 1 suất chiếu lúc 19:00 ngày mai
                showtimeValues.push([movie.id, room.id, '2026-03-27 19:00:00', 95000]);
            });
        });

        const stSql = "INSERT IGNORE INTO showtimes (movie_id, room_id, start_time, price) VALUES ?";
        await db.promise().query(stSql, [showtimeValues]);

        // 3. Tạo Ghế ngồi cho mỗi phòng (Nếu phòng đó chưa có ghế)
        // Tạo 10 ghế (A1 -> A10) cho mỗi phòng
        for (const room of rooms) {
            const [existingSeats] = await db.promise().query("SELECT id FROM seats WHERE room_id = ?", [room.id]);
            if (existingSeats.length === 0) {
                const seatValues = [];
                for (let i = 1; i <= 10; i++) {
                    seatValues.push([room.id, `A${i}`, 'Normal']);
                }
                await db.promise().query("INSERT INTO seats (room_id, seat_number, type) VALUES ?", [seatValues]);
            }
        }

        res.json({ message: "Đã tự động tạo Suất chiếu và sơ đồ Ghế thành công!" });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// 1. KẾT NỐI DATABASE (Đã cập nhật SSL cho Aiven)
// ==========================================
const db = mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT || 10944, // Ưu tiên port của biến môi trường
    ssl: {
        rejectUnauthorized: false // Bắt buộc để kết nối được với Aiven Cloud
    }
});

db.connect(err => {
    if (err) {
        console.error('❌ Lỗi kết nối MySQL:', err.message);
        return;
    }
    console.log('✅ Đã kết nối thành công Database Aiven MySQL!');
});

// 2. CÁC API LẤY DỮ LIỆU (GET)
app.get('/api/movies', (req, res) => {
    db.query("SELECT * FROM movies", (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

app.get('/api/showtimes/:movieId', (req, res) => {
    const sql = `
        SELECT s.*, r.name as room_name, c.name as cinema_name 
        FROM showtimes s
        JOIN rooms r ON s.room_id = r.id
        JOIN cinemas c ON r.cinema_id = c.id
        WHERE s.movie_id = ?
    `;
    db.query(sql, [req.params.movieId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

app.get('/api/seats/:showtimeId', (req, res) => {
    const sql = `
        SELECT s.*, 
        CASE WHEN b.id IS NOT NULL THEN 'Occupied' ELSE 'Available' END AS status
        FROM seats s
        JOIN showtimes st ON s.room_id = st.room_id
        LEFT JOIN bookings b ON s.id = b.seat_id AND b.showtime_id = st.id
        WHERE st.id = ?
    `;
    db.query(sql, [req.params.showtimeId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

// 3. API NGHIỆP VỤ (POST)

// API Đăng nhập
app.post('/api/login', (req, res) => {
    const { email, password } = req.body;
    db.query("SELECT id, full_name, email FROM users WHERE email = ? AND password = ?", 
    [email, password], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.length > 0) {
            res.json({ message: "Đăng nhập thành công", user: results[0] });
        } else {
            res.status(401).json({ error: "Sai email hoặc mật khẩu" });
        }
    });
});

// API Đặt vé (Dùng Transaction)
app.post('/api/book-tickets', (req, res) => {
    const { userId, showtimeId, seatIds, totalPrice } = req.body;

    db.beginTransaction((err) => {
        if (err) return res.status(500).json({ error: "Lỗi giao dịch" });

        const orderSql = "INSERT INTO orders (user_id, total_price, payment_status) VALUES (?, ?, 'Paid')";
        db.query(orderSql, [userId, totalPrice], (err, orderResult) => {
            if (err) return db.rollback(() => res.status(500).json({ error: "Lỗi tạo hóa đơn" }));

            const orderId = orderResult.insertId;
            const bookingValues = seatIds.map(seatId => [orderId, showtimeId, seatId]);
            const bookingSql = "INSERT INTO bookings (order_id, showtime_id, seat_id) VALUES ?";

            db.query(bookingSql, [bookingValues], (err) => {
                if (err) return db.rollback(() => res.status(400).json({ error: "Ghế đã có người đặt!" }));

                db.commit((err) => {
                    if (err) return db.rollback(() => res.status(500).json({ error: "Lỗi xác nhận" }));
                    res.json({ message: "Đặt vé thành công!", orderId: orderId });
                });
            });
        });
    });
});

// API lấy danh sách rạp
app.get('/api/cinemas', (req, res) => {
    // Nhận biến brand từ Flutter gửi lên (VD: ?brand=CGV hoặc ?brand=)
    const brand = req.query.brand; 
    
    let sql = '';
    let params = [];

    // NẾU LÀ TAB ĐỀ XUẤT (brand bị rỗng)
    if (!brand || brand === '') {
        // Lấy các rạp có điểm >= 4.5, sắp xếp ngẫu nhiên (RAND) và chỉ lấy 3 rạp
        sql = 'SELECT * FROM cinemas WHERE rating >= 4.5 ORDER BY RAND() LIMIT 3';
    } 
    // NẾU LÀ CÁC TAB KHÁC (CGV, Lotte...)
    else {
        sql = 'SELECT * FROM cinemas WHERE brand = ?';
        params = [brand];
    }

    // Chạy câu lệnh SQL
    db.query(sql, params, (err, results) => {
        if (err) {
            console.error("Lỗi MySQL:", err);
            return res.status(500).json({ error: 'Lỗi Database' });
        }
        res.json(results); // Trả mảng rạp về cho Flutter
    });
});

// ==========================================
// 4. KHỞI ĐỘNG SERVER (Đã sửa để tương thích Render)
// ==========================================
// Sử dụng process.env.PORT do Render cấp, nếu chạy ở máy thì mặc định 3000
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server backend đang chạy tại port: ${PORT}`);
});