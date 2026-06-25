const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
require ('dotenv').config();
const axios = require('axios');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const path = require('path');


const app = express();
app.use(express.json());
app.use(cors());

// 1. CẤU HÌNH LƯU TRỮ ẢNH TĨNH CHO MULTER
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'public/uploads/'); // Lưu file ảnh vào thư mục public/uploads của bạn
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname)); // Đổi tên file để không bị trùng
    }
});
const upload = multer({ storage: storage });
// Đảm bảo Node.js mở thư mục này công khai để Flutter load được Link Network Image
app.use('/uploads', express.static(path.join(__dirname, 'public/uploads')));
const paymentRoutes = require('./payment.route'); // Import file chứa router
app.use('/', paymentRoutes); // Gắn vào app
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

app.get('/api/cities', async (req, res) => {
    try {
        const [rows] = await db.promise().query('SELECT * FROM cities');
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Thêm vào file route của bạn (ví dụ: user.routes.js hoặc index.js)
app.get('/api/users/:id', (req, res) => {
    const userId = req.params.id;
    
    // Câu lệnh SQL lấy thông tin user
    const sql = 'SELECT UserID, Username, Email, Phone FROM users WHERE UserID = ?';
    
    db.query(sql, [userId], (err, results) => {
        if (err) {
            console.error('Lỗi truy vấn DB:', err);
            return res.status(500).json({ error: 'Lỗi server' });
        }
        if (results.length === 0) {
            return res.status(404).json({ message: 'Không tìm thấy user' });
        }
        
        // Trả về thông tin user đầu tiên tìm thấy
        res.status(200).json(results[0]);
    });
});
// ==========================================
// API: CẬP NHẬT THÔNG TIN TÀI KHOẢN
// ==========================================

// 1. Cập nhật Tên và Số điện thoại (Không sửa Email)
app.put('/api/user/profile/update', async (req, res) => {
    const { user_id, name, phone } = req.body;
    try {
        await db.promise().query(
            // ✅ Đã sửa 'id = ?' thành 'UserID = ?'
            'UPDATE users SET Username = ?, Phone = ? WHERE UserID = ?',
            [name, phone, user_id]
        );
        res.json({ success: true, message: "Cập nhật thông tin thành công" });
    } catch (error) {
        console.error("Lỗi update profile:", error);
        res.status(500).json({ success: false, message: "Lỗi server" });
    }
});

// 2. Đổi mật khẩu
// 2. Đổi mật khẩu (Đã nâng cấp Bcrypt)
app.put('/api/user/password/change', async (req, res) => {
    const { user_id, old_password, new_password } = req.body;
    try {
        // 1. Lấy mã Hash cũ từ database (Cột là PasswordHash)
        const [users] = await db.promise().query('SELECT PasswordHash FROM users WHERE UserID = ?', [user_id]);
        
        if (users.length === 0) {
            return res.status(404).json({ success: false, message: "Không tìm thấy User" });
        }

        const currentHash = users[0].PasswordHash;

        // 2. Dùng hàm của bcrypt để so sánh (Nó sẽ tự giải mã và đối chiếu)
        const isMatch = await bcrypt.compare(old_password, currentHash);
        
        if (!isMatch) {
            return res.status(400).json({ success: false, message: "Mật khẩu hiện tại không chính xác!" });
        }

        // 3. Nếu nhập đúng pass cũ -> Mã hóa (Hash) mật khẩu mới trước khi lưu
        // Số 12 tương ứng với độ khó (Cost factor) giống với chuẩn $2y$12$ trong CSDL của bạn
        const newHash = await bcrypt.hash(new_password, 12);

        // 4. Lưu mã hash mới xuống Database
        await db.promise().query('UPDATE users SET PasswordHash = ? WHERE UserID = ?', [newHash, user_id]);
        
        res.json({ success: true, message: "Đổi mật khẩu thành công!" });
    } catch (error) {
        console.error("Lỗi đổi pass:", error);
        res.status(500).json({ success: false, message: "Lỗi server" });
    }
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
// API TỰ ĐỘNG TẠO SUẤT CHIẾU VÀ GHẾ (Đã nâng cấp thuật toán định giá Dynamic Pricing)
app.get('/api/auto-setup', async (req, res) => {
    try {
        // =========================================================
        // 1. XÓA SẠCH RÁC: LỊCH CHIẾU, GHẾ LỖI, VÀ RẠP TỪ 2->5
        // =========================================================
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 0");
        await db.promise().query("TRUNCATE TABLE showtimes");
        await db.promise().query("TRUNCATE TABLE seats"); 
        await db.promise().query("DELETE FROM rooms WHERE Name LIKE '%Rạp 2%' OR Name LIKE '%Rạp 3%' OR Name LIKE '%Rạp 4%' OR Name LIKE '%Rạp 5%'");
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 1");

        // Hàm định nghĩa sức chứa chuẩn
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

        // ✅ HÀM MỚI: ĐỊNH GIÁ VÉ DỰA THEO THƯƠNG HIỆU RẠP & ĐỊNH DẠNG PHIM
        const getExactPrice = (cinemaName, format) => {
            const name = cinemaName.toLowerCase();
            let base = 85000;
            
            // Cấp bậc giá vé theo rạp
            if (name.includes('cgv')) base = 100000;
            else if (name.includes('lotte')) base = 95000;
            else if (name.includes('galaxy') || name.includes('bhd')) base = 90000;
            else if (name.includes('mega') || name.includes('dcine')) base = 65000;
            else if (name.includes('cinestar')) base = 55000;
            else if (name.includes('beta')) base = 50000;

            // Phụ thu theo định dạng phim chiếu
            if (format.includes('3D')) base += 30000;
            if (format.includes('IMAX')) base += 50000;
            if (format.includes('4DX')) base += 70000;
            if (format.includes('Premium')) base += 40000;

            return base;
        };

        // =========================================================
        // 2. CƯỠNG CHẾ SỬA TẤT CẢ CÁC RẠP CŨ THÀNH SỐ GHẾ CHUẨN
        // =========================================================
        const [existingRooms] = await db.promise().query("SELECT RoomID, Name FROM rooms");
        for (const room of existingRooms) {
            const exactCapacity = getExactCapacity(room.Name);
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
        
        // ✅ QUAN TRỌNG: Đã thêm gọi cột 'Name' để truy xuất tên Rạp cho việc tính tiền
        const [allRoomsFinal] = await db.promise().query("SELECT RoomID, Name, COALESCE(BufferMinutes, 10) as buffer FROM rooms");

        if (movies.length === 0) return res.status(400).json({ error: "Vui lòng chạy sync-movies trước!" });

        const showtimeValues = [];
        const daysToSchedule = 7; 
        const now = new Date();
        let movieIndex = 0; 

        const formatOptions = ['2D Phụ đề',  '2D Phụ đề', '2D Lồng Tiếng', '2D Phụ đề', 'IMAX 3D', '4DX', '3D Phụ đề', '2D Premium'];

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

                    const randomFormat = formatOptions[Math.floor(Math.random() * formatOptions.length)];

                    // ✅ Tính giá tiền cuối cùng dựa vào Tên rạp (room.Name) và Định dạng (randomFormat)
                    const finalPrice = getExactPrice(room.Name, randomFormat);

                    showtimeValues.push([currentMovie.id, room.RoomID, formattedStartTime, finalPrice, isCinetour, randomFormat]);

                    const totalMinutesToAdd = currentMovie.duration + room.buffer + 10; 
                    currentStartTime.setMinutes(currentStartTime.getMinutes() + totalMinutesToAdd);
                }
            }
        }

        if (showtimeValues.length > 0) {
            await db.promise().query("INSERT INTO showtimes (MovieID, RoomID, StartTime, Price, cinetour, movie_format) VALUES ?", [showtimeValues]);
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
            message: `🔥 ĐÃ CƯỠNG CHẾ THÀNH CÔNG: Tự động đúc chuẩn xác ${totalSeatsInserted} ghế. Đã tạo ${showtimeValues.length} suất chiếu với giá linh động (Dynamic Pricing)!` 
        });
    } catch (error) {
        console.error("Lỗi auto-setup:", error);
        res.status(500).json({ error: error.message });
    }
});
// ==============================================================
// API: DỌN DẸP RÁC THÔNG MINH (SMART CLEAN-UP)
// Giải phóng dung lượng tối đa mà vẫn giữ nguyên Lịch Sử Khách Hàng
// ==============================================================
app.get('/api/clean-up', async (req, res) => {
    try {
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 0");

        // 1. DỌN VÉ KẸT: Xóa các ghế khách đang bấm chọn dở dang nhưng thoát app (quá 10 phút)
        const [holdResult] = await db.promise().query(`
            DELETE FROM seatholds WHERE ExpiredAt < NOW()
        `);

        // 2. DỌN HÓA ĐƠN RÁC: Xóa các chi tiết ghế của Hóa Đơn chưa thanh toán (Pending) quá 30 phút
        await db.promise().query(`
            DELETE bs FROM bookingseats bs 
            JOIN bookings b ON bs.BookingID = b.BookingID 
            WHERE b.Status = 'Pending' AND b.CreatedAt < DATE_SUB(NOW(), INTERVAL 30 MINUTE)
        `);

        // 3. DỌN HÓA ĐƠN RÁC: Xóa các Hóa Đơn chưa thanh toán (Pending) quá 30 phút
        const [bookingResult] = await db.promise().query(`
            DELETE FROM bookings 
            WHERE Status = 'Pending' AND CreatedAt < DATE_SUB(NOW(), INTERVAL 30 MINUTE)
        `);

        // ==============================================================
        // 4. 🔥 SIÊU TỐI ƯU DUNG LƯỢNG (DEEP CLEAN SEATS) 🔥
        // Xóa TẤT CẢ các ghế của những phòng thuộc suất chiếu đã qua, 
        // NGOẠI TRỪ những ghế đã được khách thanh toán thành công hoặc đang chờ hoàn tiền.
        // ==============================================================
        const [seatResult] = await db.promise().query(`
            DELETE s FROM seats s
            JOIN showtimes st ON s.RoomID = st.RoomID
            WHERE st.StartTime < DATE_ADD(NOW(), INTERVAL 7 HOUR)
              AND s.SeatID NOT IN (
                  SELECT SeatID FROM bookingseats bs 
                  JOIN bookings b ON bs.BookingID = b.BookingID
                  WHERE b.Status IN ('Paid', 'Refund Pending', 'Refunded')
              )
        `);

        // ==============================================================
        // 5. 🧹 CHUYÊN GIA DỌN DẸP SUẤT CHIẾU (NEW) 🧹
        // Xóa các suất chiếu đã qua (nhỏ hơn hiện tại) 
        // MÀ KHÔNG CÓ BẤT KỲ VÉ NÀO ĐƯỢC BÁN (Không nằm trong bảng bookings hợp lệ)
        // ==============================================================
        const [showtimeResult] = await db.promise().query(`
            DELETE FROM showtimes
            WHERE StartTime < DATE_ADD(NOW(), INTERVAL 7 HOUR)
              AND ShowtimeID NOT IN (
                  SELECT DISTINCT ShowtimeID FROM bookings 
                  WHERE Status IN ('Paid', 'Refund Pending', 'Refunded')
              )
        `);

        await db.promise().query("SET FOREIGN_KEY_CHECKS = 1");

        res.json({ 
            success: true, 
            message: `🧹 ĐÃ DỌN DẸP TOÀN DIỆN HỆ THỐNG!
            - Giải phóng: ${holdResult.affectedRows} ghế bị kẹt.
            - Hủy: ${bookingResult.affectedRows} hóa đơn rác.
            - Xóa: ${seatResult.affectedRows} ghế trống thừa thãi của suất cũ.
            - 🚀 Quét sạch: ${showtimeResult.affectedRows} suất chiếu "ế" không bán được vé nào!
            => Server siêu nhẹ, Lịch sử User vẫn được BẢO TOÀN 100%! 🛡️` 
        });
    } catch (error) {
        console.error("Lỗi dọn dẹp:", error);
        res.status(500).json({ error: error.message });
    }
});
// ==========================================
// API LẤY DANH SÁCH BẮP NƯỚC (FOODS)
// ==========================================
app.get('/api/foods', (req, res) => {
    // Cho phép lọc theo brand_id nếu cần (VD: /api/foods?brand_id=1)
    const brandId = req.query.brand_id;
    
    let query = "SELECT FoodID, Name, description, Price, ImageURL, Type, brand_id FROM foods";
    let params = [];
    
    if (brandId) {
        query += " WHERE brand_id = ?";
        params.push(brandId);
    }
    
    db.query(query, params, (err, results) => {
        if (err) {
            console.error("❌ Lỗi lấy danh sách bắp nước:", err);
            return res.status(500).json({ error: "Lỗi khi lấy dữ liệu bắp nước" });
        }
        res.json(results);
    });
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
        // ✅ ĐÃ SỬA: Lấy 'brand_id' (là số) thay vì chữ
        const brandId = req.query.brand_id; 
        const isRandom = req.query.random; 

        let sql = '';
        let params = [];

        if (isRandom === 'true') {
            sql = 'SELECT * FROM cinemas WHERE rating >= 4.5 AND IsDeleted = 0 ORDER BY RAND() LIMIT 3';
        } 
        // ✅ ĐÃ SỬA: Kiểm tra nếu có brandId thì truy vấn theo cột brand_id
        else if (brandId && brandId.trim() !== '') {
            sql = 'SELECT * FROM cinemas WHERE brand_id = ? AND IsDeleted = 0';
            params = [parseInt(brandId)]; // Ép kiểu về số nguyên
        } 
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

    // ==========================================
    // ✅ ĐÃ SỬA: Đổi Status thành 'Occupied' và tối ưu bỏ JOIN thừa
    // Thêm chữ 'Pending' để trừ luôn những ghế khách khác đang giữ lúc thanh toán VNPAY
    // ==========================================
    const sql = `
        SELECT 
            s.ShowtimeID, s.StartTime, s.EndTime, s.Price, s.cinetour AS IsCinetour,
            s.movie_format, r.Name AS RoomName, r.TotalSeats, 
            (r.TotalSeats - (
                SELECT COUNT(bs.SeatID) 
                FROM bookingseats bs 
                WHERE bs.ShowtimeID = s.ShowtimeID 
                  AND bs.Status IN ('Occupied', 'Pending')
            )) AS AvailableSeats
        FROM showtimes s
        JOIN rooms r ON s.RoomID = r.RoomID
        WHERE s.MovieID = ? AND r.CinemaID = ? AND DATE(s.StartTime) = ?
          AND s.StartTime > DATE_ADD(NOW(), INTERVAL 7 HOUR)  /* ✅ ĐÃ THÊM: CHỈ LẤY SUẤT CHIẾU TRONG TƯƠNG LAI */
        ORDER BY s.StartTime ASC
    `;

    db.query(sql, [movieId, cinemaId, date], (err, results) => {
        if (err) {
            console.error("❌ Lỗi Database /api/showtimes:", err.message);
            return res.status(500).json({ error: err.message });
        }
        res.json(results);
    });
});

// ===================================================================
// 2. API DÀNH RIÊNG CHO ĐỔI SUẤT CHIẾU (Lấy TẤT CẢ rạp)
// ===================================================================
app.get('/api/showtimes-all', (req, res) => {
    const movieId = req.query.movie_id;
    const date = req.query.date;

    if (!movieId || !date) {
        return res.status(400).json({ error: "Thiếu tham số (movie_id, date)!" });
    }

    // ✅ ĐÃ SỬA: Bỏ JOIN không cần thiết và đổi Status thành 'Occupied'
    const sql = `
        SELECT 
            s.ShowtimeID, s.StartTime, s.EndTime, s.Price, s.cinetour AS IsCinetour,s.movie_format,
            r.Name AS RoomName, c.Name AS cinema_name, r.TotalSeats, 
            (r.TotalSeats - (
                SELECT COUNT(bs.SeatID) 
                FROM bookingseats bs 
                WHERE bs.ShowtimeID = s.ShowtimeID 
                  AND bs.Status = 'Occupied'
            )) AS AvailableSeats
        FROM showtimes s
        JOIN rooms r ON s.RoomID = r.RoomID
        JOIN cinemas c ON r.CinemaID = c.id 
        WHERE s.MovieID = ? AND DATE(s.StartTime) = ?
          AND s.StartTime > DATE_ADD(NOW(), INTERVAL 7 HOUR)  /* ✅ ĐÃ THÊM: CHỈ LẤY SUẤT CHIẾU TRONG TƯƠNG LAI */
        ORDER BY s.StartTime ASC
    `;

    db.query(sql, [movieId, date], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

// =======================================================
// TÍNH NĂNG GIỮ GHẾ THỜI GIAN THỰC (REAL-TIME SEAT HOLD)
// =======================================================

// 1. API: KHÓA GHẾ (Khi khách vừa bấm chọn ghế trên app)
app.post('/api/seats/hold', async (req, res) => {
    const { userId, showtimeId, seatId } = req.body;
    try {
        // Thêm vào bảng seatholds với thời gian sống là 10 phút
        const sql = `
            INSERT INTO seatholds (UserID, ShowtimeID, SeatID, ExpiredAt, Status) 
            VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE), 'holding')
        `;
        await db.promise().query(sql, [userId, showtimeId, seatId]);
        res.json({ success: true, message: "Đã khóa ghế" });
    } catch (error) {
        console.error("Lỗi hold ghế:", error);
        res.status(500).json({ error: error.message });
    }
});

// 2. API: NHẢ GHẾ (Khi khách bấm bỏ chọn ghế)
app.post('/api/seats/release', async (req, res) => {
    const { userId, showtimeId, seatId } = req.body;
    try {
        const sql = `DELETE FROM seatholds WHERE UserID = ? AND ShowtimeID = ? AND SeatID = ?`;
        await db.promise().query(sql, [userId, showtimeId, seatId]);
        res.json({ success: true, message: "Đã nhả ghế" });
    } catch (error) {
        console.error("Lỗi nhả ghế:", error);
        res.status(500).json({ error: error.message });
    }
});

// 3. API: TẢI SƠ ĐỒ GHẾ VÀ TỰ ĐỘNG DỌN RÁC
app.get('/api/seats/:showtimeId', async (req, res) => {
    const showtimeId = req.params.showtimeId;
    try {
        // BƯỚC A: DỌN DẸP THỤ ĐỘNG
        // Mỗi lần có khách mở sơ đồ rạp lên, hệ thống sẽ âm thầm quét và xóa sạch những ghế đã giữ quá 10 phút.
        await db.promise().query(`DELETE FROM seatholds WHERE ExpiredAt <= NOW()`);

        // BƯỚC B: Tải sơ đồ ghế (Ghép cả ghế đã mua và ghế khách khác đang giữ)
        const sql = `
            SELECT s.SeatID, s.SeatNumber, 
                   stype.TypeName AS SeatType,
                   CASE 
                       WHEN bs.SeatID IS NOT NULL THEN 'Occupied' -- Ghế đã thanh toán / đang ở cổng VNPAY
                       WHEN sh.SeatID IS NOT NULL THEN 'Occupied' -- Ghế đang bị khách khác bấm giữ
                       ELSE 'Available' 
                   END AS status
            FROM seats s
            JOIN showtimes st ON s.RoomID = st.RoomID
            JOIN seattypes stype ON s.SeatTypeID = stype.SeatTypeID
            LEFT JOIN bookingseats bs ON s.SeatID = bs.SeatID AND bs.ShowtimeID = ? AND bs.Status IN ('Occupied', 'Pending')
            LEFT JOIN seatholds sh ON s.SeatID = sh.SeatID AND sh.ShowtimeID = ? 
            WHERE st.ShowtimeID = ?
        `;
        const [results] = await db.promise().query(sql, [showtimeId, showtimeId, showtimeId]);
        res.json(results);
    } catch (error) {
        console.error("Lỗi tải sơ đồ ghế:", error);
        res.status(500).json({ error: err.message });
    }
});


// ==========================================
// 4. API NGHIỆP VỤ (POST)
// ==========================================

// API Đăng nhập
app.post('/api/login', (req, res) => {
    const { email, password } = req.body;
    
    // 1. CHỈ TÌM THEO EMAIL (Nhớ gọi thêm cột PasswordHash ra để đối chiếu)
    const sql = "SELECT UserID, Username, Email, Phone, Avatar, PasswordHash FROM users WHERE Email = ?";
    
    db.query(sql, [email], async (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        
        // Nếu không có email này trong CSDL
        if (results.length === 0) {
            return res.status(401).json({ error: "Email không tồn tại" });
        }

        const user = results[0];

        try {
            // 2. SO SÁNH MẬT KHẨU GỐC VỚI CHUỖI MÃ HÓA TRONG DATABASE
            const isMatch = await bcrypt.compare(password, user.PasswordHash);

            if (isMatch) {
                // Đăng nhập thành công -> Xóa cục mật khẩu đi trước khi gửi về app để bảo mật
                delete user.PasswordHash;
                res.json({ message: "Đăng nhập thành công", user: user });
            } else {
                // Sai mật khẩu
                res.status(401).json({ error: "Sai mật khẩu" });
            }
        } catch (error) {
            console.error("Lỗi giải mã:", error);
            res.status(500).json({ error: "Lỗi hệ thống khi xác thực" });
        }
    });
});

// API Đặt vé (Đã fix lỗi Pool Transaction, chống Double Booking và DỌN RÁC SEATHOLDS)
// API Đặt vé (Đã fix triệt để lỗi kẹt ghế ở bảng seatholds)
app.post('/api/book-tickets', (req, res) => {
    const { userId, showtimeId, seatIds, totalPrice } = req.body;

    if (!seatIds || !Array.isArray(seatIds) || seatIds.length === 0) {
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
                
                // 2. Chốt ghế vào bảng bookingseats
                const bookingSeatValues = seatIds.map(seatId => [bookingId, showtimeId, seatId, pricePerSeat, 'Booked']);
                const seatSql = "INSERT INTO bookingseats (BookingID, ShowtimeID, SeatID, Price, Status) VALUES ?";

                connection.query(seatSql, [bookingSeatValues], (err) => {
                    if (err) {
                        return connection.rollback(() => {
                            connection.release();
                            res.status(400).json({ error: "Thất bại: Ghế đã có người đặt trước!" });
                        });
                    }

                    // ==============================================================
                    // 3. ✅ QUAN TRỌNG: DỌN RÁC SEATHOLDS (KHÔNG DÙNG USERID NỮA)
                    // Kỹ thuật Dynamic Placeholders để xóa chính xác mọi ID ghế được truyền vào
                    // ==============================================================
                    const placeholders = seatIds.map(() => '?').join(',');
                    const deleteHoldSql = `DELETE FROM seatholds WHERE ShowtimeID = ? AND SeatID IN (${placeholders})`;
                    
                    // Gộp mảng tham số để truyền vào SQL: [8436, 11783, 11784...]
                    const deleteParams = [showtimeId, ...seatIds];

                    connection.query(deleteHoldSql, deleteParams, (err, deleteResult) => {
                        if (err) {
                            console.error("❌ Lỗi khi xóa ghế holding:", err);
                        } else {
                            // In ra log để bạn kiểm tra tận mắt xem nó xóa được bao nhiêu ghế
                            console.log(`✅ Đã dọn dẹp thành công ${deleteResult.affectedRows} ghế chờ (holding) khỏi Database!`);
                        }

                        // 4. Chốt giao dịch
                        connection.commit((err) => {
                            if (err) {
                                return connection.rollback(() => {
                                    connection.release();
                                    res.status(500).json({ error: "Lỗi xác nhận" });
                                });
                            }
                            connection.release();
                            res.json({ message: "🎉 Đặt vé thành công! Đã dọn sạch ghế chờ.", bookingId: bookingId });
                        });
                    });
                });
            });
        });
    });
});
// API: Lấy tổng tiền chi tiêu của một User
app.get('/api/user/total-spent/:userId', (req, res) => {
    const userId = req.params.userId;
    
    // Tính tổng tiền của hóa đơn (Bao gồm ghế và bắp nước)
    const sql = "SELECT SUM(TotalAmount) AS totalSpent FROM bookings WHERE UserID = ?";
    
    db.query(sql, [userId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        
        const total = results[0].totalSpent || 0; 
        res.json({ totalSpent: total });
    });
});
// API: Lấy Lịch sử Giao dịch (Gộp cả Ghế và Bắp Nước)
app.get('/api/user/tickets/:userId', (req, res) => {
    const userId = req.params.userId;
    
    const sql = `
        SELECT 
            m.title AS movie, 
            m.poster_path AS image, 
            m.backdrop_path AS backdrop, 
            
            IF(st.StartTime IS NOT NULL,
                CONCAT(
                    DATE_FORMAT(st.StartTime, '%H:%i'), 
                    ' - ', 
                    DATE_FORMAT(DATE_ADD(st.StartTime, INTERVAL COALESCE(m.duration, 120) MINUTE), '%H:%i'), 
                    ' | ', 
                    DATE_FORMAT(st.StartTime, '%d/%m/%Y')
                ),
                CONCAT('Nhận trong ngày | ', DATE_FORMAT(b.CreatedAt, '%d/%m/%Y'))
            ) AS date, 
            
            c.name AS cinema, 
            
            -- =======================================================
            -- ✅ THÊM DÒNG NÀY: Bốc cột 'address' từ DB lên và đặt tên là 'cinema_address'
            -- =======================================================
            c.address AS cinema_address, 
            
            IFNULL(r.Name, 'Quầy Bắp Nước') AS room, 
            
            b.TotalAmount AS price, 
            b.Status AS status, 
            b.BookingID AS code, 
            
            COALESCE(
                (SELECT QRCode FROM bookingseats WHERE BookingID = b.BookingID LIMIT 1),
                (SELECT QRCode FROM bookingfoods WHERE BookingID = b.BookingID LIMIT 1)
            ) AS QRCode,
            
            (SELECT GROUP_CONCAT(s2.SeatNumber SEPARATOR ', ') 
             FROM bookingseats bs2 JOIN seats s2 ON bs2.SeatID = s2.SeatID 
             WHERE bs2.BookingID = b.BookingID) AS seats,
             
            (SELECT JSON_ARRAYAGG(JSON_OBJECT('name', f.Name, 'qty', bf.Quantity, 'image', IFNULL(f.ImageURL, ''), 'desc', IFNULL(f.description, ''))) 
             FROM bookingfoods bf JOIN foods f ON bf.FoodID = f.FoodID 
             WHERE bf.BookingID = b.BookingID) AS foods
             
        FROM bookings b
        LEFT JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
        LEFT JOIN movies m ON st.MovieID = m.id 
        LEFT JOIN rooms r ON st.RoomID = r.RoomID
        LEFT JOIN cinemas c ON c.id = COALESCE(r.CinemaID, b.CinemaID)
        
        WHERE b.UserID = ?
        ORDER BY b.CreatedAt DESC
    `;
    
    db.query(sql, [userId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

// ==========================================
// 0. API: THỐNG KÊ SỐ LƯỢNG (ĐÃ FIX: CHỈ ĐẾM REVIEW GỐC, KHÔNG ĐẾM REPLY)
// ==========================================
app.get('/api/user/stats/:userId', async (req, res) => {
    const userId = req.params.userId;

    try {
        const [movieData, voucherData, reviewData] = await Promise.all([
            
            // 1. Đếm Phim đã xem
            db.promise().query(
                `SELECT COUNT(DISTINCT b.BookingID) AS count 
                 FROM bookings b 
                 JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID 
                 WHERE b.UserID = ? AND st.StartTime < NOW()`, 
                [userId]
            ).catch(e => { 
                console.error("Lỗi đếm phim:", e.message); 
                return [[{ count: 0 }]]; 
            }),

            // 2. Đếm Voucher chưa dùng (Đã sửa: Chấp nhận cả Used bằng 0 hoặc bị NULL)
            db.promise().query(
                "SELECT COUNT(*) AS count FROM uservouchers WHERE UserID = ? AND (Used = 0 OR Used IS NULL OR Status = 0 OR Status IS NULL)", 
                [userId]
            ).catch(e => { 
                console.error("Lỗi đếm voucher:", e.message); 
                return [[{ count: 0 }]]; 
            }),

            // 3. Đếm Đánh giá (Chỉ đếm review gốc, bỏ qua reply)
            db.promise().query(
                "SELECT COUNT(*) AS count FROM comments WHERE UserID = ? AND MovieID IS NOT NULL AND ParentID IS NULL", 
                [userId]
            ).catch(e => { 
                console.error("Lỗi đếm đánh giá:", e.message); 
                return [[{ count: 0 }]]; 
            })
        ]);

        // =========================================================================
        // ✅ ĐÃ SỬA: Dùng Optional Chaining (?.) để chống sập Server nếu DB trả về rỗng
        // ✅ ĐÃ SỬA: Bọc Number() để ép kiểu về số nguyên chuẩn, tránh lỗi String bên Flutter
        // =========================================================================
        const watchedMovies = Number(movieData[0]?.[0]?.count || 0);
        const vouchers = Number(voucherData[0]?.[0]?.count || 0);
        const reviews = Number(reviewData[0]?.[0]?.count || 0);

        res.status(200).json({ vouchers, watchedMovies, reviews });

    } catch (error) {
        console.error("❌ Lỗi API stats tổng:", error.message);
        res.status(500).json({ vouchers: 0, watchedMovies: 0, reviews: 0 });
    }
});
// ==========================================
// 1. API: Lấy danh sách Ví Voucher (Gồm Đã lưu và Đã sử dụng)
// ==========================================
app.get('/api/user/vouchers/:userId', async (req, res) => {
    const userId = req.params.userId;
    try {
        const sql = `
            SELECT id, code AS VoucherCode, discount_amount AS Discount, 
                   DATE_FORMAT(expired_date, '%d/%m/%Y') AS ExpiredDate, Used 
            FROM uservouchers 
            WHERE UserID = ? 
            ORDER BY expired_date ASC
        `;
        const [results] = await db.promise().query(sql, [userId]);
        res.json(results);
    } catch (error) {
        res.json([]); 
    }
});

// ==========================================
// 2. API: Lấy danh sách Phim đã xem (Để lọc theo tháng)
// ==========================================
app.get('/api/user/watched-movies/:userId', async (req, res) => {
    const userId = req.params.userId;
    try {
        const sql = `
            SELECT 
                m.id AS movieId,
                m.title AS movie, 
                m.poster_path AS image, 
                DATE_FORMAT(st.StartTime, '%m/%Y') AS month_year, 
                DATE_FORMAT(st.StartTime, '%H:%i - %d/%m/%Y') AS date,
                c.name AS cinema
            FROM bookings b 
            JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID 
            JOIN movies m ON st.MovieID = m.id 
            JOIN rooms r ON st.RoomID = r.RoomID
            JOIN cinemas c ON r.CinemaID = c.id
            WHERE b.UserID = ? AND st.StartTime < NOW()
            GROUP BY b.BookingID, m.id, m.title, m.poster_path, st.StartTime, c.name
            ORDER BY st.StartTime DESC
        `;
        const [results] = await db.promise().query(sql, [userId]);
        res.json(results);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});


// ==========================================
// 3. API: Lấy danh sách Đánh giá của User (CHỈ LẤY REVIEW GỐC)
// ==========================================
app.get('/api/user/reviews/:userId', async (req, res) => {
    const userId = req.params.userId;
    try {
        const sql = `
            SELECT 
                cm.CommentID AS commentId,
                cm.Content AS comment,
                cm.Rating AS rating,
                cm.Tags AS tags,
                cm.ImageURL AS image,
                DATE_FORMAT(cm.CreatedAt, '%H:%i - %d/%m/%Y') AS date,
                cm.CreatedAt AS rawDate,
                
                m.id AS movieId,
                m.title AS movie, 
                m.poster_path AS poster_path,
                m.backdrop_path AS backdrop_path,
                m.genres AS genres,
                m.overview AS overview,
                m.vote_average AS vote_average,
                
                u.Username AS username,
                u.Avatar AS avatar,
                u.UserID AS userId,
                
                (SELECT COUNT(*) FROM comment_likes WHERE CommentID = cm.CommentID) as likeCount,
                (SELECT ReactionType FROM comment_likes WHERE CommentID = cm.CommentID AND UserID = ?) as userReaction,
                (SELECT GROUP_CONCAT(DISTINCT ReactionType) FROM comment_likes WHERE CommentID = cm.CommentID) as topReactions,
                (SELECT COUNT(*) FROM comments sub WHERE sub.ParentID = cm.CommentID OR sub.ParentID IN (SELECT CommentID FROM comments WHERE ParentID = cm.CommentID)) as replyCount
            FROM comments cm
            JOIN movies m ON cm.MovieID = m.id
            JOIN users u ON cm.UserID = u.UserID
            -- ✅ CHỈ LẤY REVIEW GỐC (ParentID IS NULL) VÀ KHÔNG LẤY BÌNH LUẬN TRONG NHÓM
            WHERE cm.UserID = ? AND cm.MovieID IS NOT NULL AND cm.ParentID IS NULL
            ORDER BY cm.CreatedAt DESC
        `;
        // Truyền userId 2 lần: 1 cho userReaction, 1 cho WHERE
        const [results] = await db.promise().query(sql, [userId, userId]);
        res.json(results);
    } catch (error) {
        console.error("❌ Lỗi lấy lịch sử đánh giá:", error);
        res.json([]); 
    }
});

// =======================================================================
// CÁC API DÀNH RIÊNG CHO TRANG "CHI TIẾT ĐÁNH GIÁ PHIM" (Giống Facebook)
// =======================================================================
// =======================================================================
// API: SỬA BÀI ĐÁNH GIÁ PHIM BỞI TÁC GIẢ
// =======================================================================
app.put('/api/movies/reviews/:reviewId', upload.single('image'), async (req, res) => {
    const reviewId = req.params.reviewId;
    const { user_id, rating, content, tags, keep_old_image } = req.body;
    const imageUrl = req.file ? req.file.filename : null;

    try {
        // Kiểm tra quyền tác giả
        const [check] = await db.promise().query('SELECT UserID FROM comments WHERE CommentID = ?', [reviewId]);
        if (check.length === 0 || check[0].UserID.toString() !== user_id.toString()) {
            return res.status(403).json({ error: "Không có quyền sửa đánh giá này!" });
        }

        let sql = '';
        let params = [];

        // Trường hợp 1: Có upload ảnh mới
        if (imageUrl) {
            sql = 'UPDATE comments SET Rating = ?, Content = ?, Tags = ?, ImageURL = ? WHERE CommentID = ?';
            params = [rating, content || '', tags || '', imageUrl, reviewId];
        } 
        // Trường hợp 2: Không up ảnh mới, và bấm XÓA ẢNH CŨ (keep_old_image = false)
        else if (keep_old_image === 'false') {
            sql = 'UPDATE comments SET Rating = ?, Content = ?, Tags = ?, ImageURL = NULL WHERE CommentID = ?';
            params = [rating, content || '', tags || '', reviewId];
        } 
        // Trường hợp 3: Chỉ sửa chữ, giữ nguyên ảnh cũ (keep_old_image = true)
        else {
            sql = 'UPDATE comments SET Rating = ?, Content = ?, Tags = ? WHERE CommentID = ?';
            params = [rating, content || '', tags || '', reviewId];
        }

        await db.promise().query(sql, params);
        res.json({ success: true, message: "Đã cập nhật đánh giá thành công!" });
    } catch (error) {
        console.error("❌ Lỗi sửa đánh giá:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// =======================================================================
// 1. API: Thả cảm xúc (Like, Tim, Haha...) cho Bài Đánh Giá (ĐÃ FIX LỖI SPAM CLICK)
// =======================================================================
app.post('/api/movies/reviews/react', async (req, res) => {
    const { user_id, comment_id, reaction_type } = req.body;
    try {
        const [existing] = await db.promise().query('SELECT * FROM comment_likes WHERE CommentID = ? AND UserID = ?', [comment_id, user_id]);
        
        if (existing.length > 0) {
            if (existing[0].ReactionType === reaction_type) {
                // Bấm lại cảm xúc cũ -> Hủy
                await db.promise().query('DELETE FROM comment_likes WHERE CommentID = ? AND UserID = ?', [comment_id, user_id]);
            } else {
                // Đổi sang cảm xúc khác
                await db.promise().query('UPDATE comment_likes SET ReactionType = ? WHERE CommentID = ? AND UserID = ?', [reaction_type, comment_id, user_id]);
            }
        } else {
            // Chưa thả -> Thêm mới (CÓ BỌC BẮT LỖI SPAM CLICK TỪ NGƯỜI DÙNG)
            try {
                await db.promise().query('INSERT INTO comment_likes (CommentID, UserID, ReactionType) VALUES (?, ?, ?)', [comment_id, user_id, reaction_type]);
            } catch (insertErr) {
                // Bắt chính xác lỗi ER_DUP_ENTRY (1062) do bấm liên tục
                if (insertErr.code === 'ER_DUP_ENTRY') {
                    // Nếu trùng, ép nó cập nhật đè lên luôn để không bị sập Server
                    await db.promise().query('UPDATE comment_likes SET ReactionType = ? WHERE CommentID = ? AND UserID = ?', [reaction_type, comment_id, user_id]);
                } else {
                    throw insertErr; // Lỗi khác thì quăng ra catch tổng
                }
            }
        }
        res.json({ success: true });
    } catch (error) {
        console.error("Lỗi thả cảm xúc đánh giá phim:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 2. API: Lấy danh sách bình luận con (Reply) bên dưới 1 Bài Đánh Giá
// 2. API: Lấy danh sách bình luận con (Reply) bên dưới 1 Bài Đánh Giá
app.get('/api/movies/reviews/:reviewId/comments', async (req, res) => {
    const reviewId = req.params.reviewId;
    const userId = req.query.user_id || 0; 
    try {
        const sql = `
            SELECT c.CommentID as commentId, c.Content as comment, c.CreatedAt as rawDate, c.ImageURL as image,
                   
                   -- ✅ SỬA LỖI 1: BẮT BUỘC PHẢI TRẢ VỀ PARENT_ID ĐỂ FLUTTER BIẾT AI LÀ CON CỦA AI
                   c.ParentID as parentId, 
                   
                   u.Username as username, u.Avatar as avatar, u.UserID as userId,
                   
                   -- Đếm số Like và lấy cảm xúc của user đối với bình luận con này
                   (SELECT COUNT(*) FROM comment_likes WHERE CommentID = c.CommentID) as likeCount,
                   (SELECT ReactionType FROM comment_likes WHERE CommentID = c.CommentID AND UserID = ?) as userReaction,
                   (SELECT GROUP_CONCAT(DISTINCT ReactionType) FROM comment_likes WHERE CommentID = c.CommentID) as topReactions
            FROM comments c
            JOIN users u ON c.UserID = u.UserID
            
            -- ✅ SỬA LỖI 2: LẤY CẢ BÌNH LUẬN CON (CẤP 1) VÀ BÌNH LUẬN CHÁU (CẤP 2)
            WHERE c.ParentID = ? OR c.ParentID IN (SELECT CommentID FROM comments WHERE ParentID = ?)
            
            ORDER BY c.CreatedAt ASC
        `;
        
        // Nhớ truyền đủ 3 tham số: userId, reviewId (cho con), reviewId (cho cháu)
        const [comments] = await db.promise().query(sql, [userId, reviewId, reviewId]);
        res.json(comments);
    } catch (error) {
        console.error("Lỗi lấy bình luận con của đánh giá:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 3. API: Đăng bình luận con (Reply) vào Bài Đánh Giá (Hỗ trợ upload ảnh)
app.post('/api/movies/reviews/:reviewId/comments', upload.single('image'), async (req, res) => {
    const reviewId = req.params.reviewId;
    // ✅ FIX 1: Hứng thêm biến ParentID và parent_id từ Flutter gửi lên
    const { user_id, content, ParentID, parent_id } = req.body; 
    const imageUrl = req.file ? req.file.filename : null;

    try {
        // Lấy MovieID của bài đánh giá gốc để lưu vào bình luận con
        const [originalReview] = await db.promise().query('SELECT MovieID FROM comments WHERE CommentID = ? LIMIT 1', [reviewId]);
        const movieId = originalReview.length > 0 ? originalReview[0].MovieID : null;

        // ✅ FIX 2: Ưu tiên lấy ID bình luận lồng nhau, nếu không có thì mới lấy ID của bài Review
        const actualParentId = ParentID || parent_id || reviewId;

        await db.promise().query(
            'INSERT INTO comments (MovieID, UserID, Content, ParentID, CreatedAt, ImageURL) VALUES (?, ?, ?, ?, NOW(), ?)',
            [movieId, user_id, content || '', actualParentId, imageUrl]
        );
        res.json({ success: true, message: "Trả lời đánh giá thành công!" });
    } catch (error) {
        console.error("Lỗi trả lời đánh giá:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// =======================================================================
// API: ĐĂNG ĐÁNH GIÁ MỚI CHO BỘ PHIM (CÓ LƯU TAGS VÀ HÌNH ẢNH)
// =======================================================================
app.post('/api/movies/reviews', upload.single('image'), async (req, res) => {
    // Hứng dữ liệu từ Flutter gửi lên
    const { user_id, movie_id, rating, content, tags } = req.body; 
    // Hứng file ảnh (nếu người dùng có đính kèm)
    const imageUrl = req.file ? req.file.filename : null; 

    try {
        // Câu lệnh SQL chèn vào bảng comments
        // (Đánh giá gốc của phim thì không có ParentID nên để mặc định là NULL)
        const sql = `
            INSERT INTO comments (UserID, MovieID, Rating, Content, Tags, ImageURL, CreatedAt) 
            VALUES (?, ?, ?, ?, ?, ?, NOW())
        `;
        
        await db.promise().query(sql, [
            user_id, 
            movie_id, 
            rating, 
            content || '', 
            tags || '', 
            imageUrl
        ]);
        
        res.status(200).json({ success: true, message: "Thêm đánh giá thành công!" });
    } catch (error) {
        console.error("❌ Lỗi khi thêm đánh giá phim:", error);
        res.status(500).json({ error: "Lỗi server khi thêm đánh giá" });
    }
});
// =======================================================================
// API: LẤY TẤT CẢ ĐÁNH GIÁ CỦA MỘT BỘ PHIM (ĐÃ FIX LỖI TÌM MOVIEID VÀ ĐẾM TỔNG BÌNH LUẬN)
// =======================================================================
app.get('/api/movies/:movieId/reviews', async (req, res) => {
    const movieId = req.params.movieId;
    const userId = req.query.user_id || 0; 
    try {
        const sql = `
            SELECT 
                cm.CommentID AS commentId,
                cm.Content AS comment,
                cm.Rating AS rating,
                cm.ImageURL AS image,
                DATE_FORMAT(cm.CreatedAt, '%d/%m/%Y') AS date,
                
                -- ✅ BỔ SUNG 1: Lấy thời gian gốc để Flutter tính "Vừa xong", "1 giờ trước"
                cm.CreatedAt AS rawDate, 
                
                -- ✅ BỔ SUNG 2: Lấy chuỗi Tag người dùng đã chọn
                cm.Tags AS tags,         

                -- ✅ BỔ SUNG 3 (ĐÃ SỬA): JOIN bảng showtimes để tìm đúng phim, và chỉ tính vé 'Paid'
                (SELECT IF(COUNT(*) > 0, true, false) 
                 FROM bookings b 
                 JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID 
                 WHERE b.UserID = cm.UserID AND st.MovieID = cm.MovieID AND b.Status = 'Paid'
                ) AS hasBoughtTicket,

                u.Username AS username,
                u.Avatar AS avatar,
                
                -- Đếm số Like và lấy cảm xúc của user
                (SELECT COUNT(*) FROM comment_likes WHERE CommentID = cm.CommentID) as likeCount,
                (SELECT ReactionType FROM comment_likes WHERE CommentID = cm.CommentID AND UserID = ?) as userReaction,
                (SELECT GROUP_CONCAT(DISTINCT ReactionType) FROM comment_likes WHERE CommentID = cm.CommentID) as topReactions,
                
                -- ✅ CHỖ ĐÃ SỬA: Đếm số bình luận con (Lấy cả Cấp 1 và Cấp 2)
                (SELECT COUNT(*) FROM comments sub 
                 WHERE sub.ParentID = cm.CommentID 
                    OR sub.ParentID IN (SELECT CommentID FROM comments WHERE ParentID = cm.CommentID)
                ) as replyCount
                
            FROM comments cm
            JOIN users u ON cm.UserID = u.UserID
            WHERE cm.MovieID = ? AND cm.ParentID IS NULL
            ORDER BY cm.CreatedAt DESC
        `;
        const [results] = await db.promise().query(sql, [userId, movieId]);
        res.json(results);
    } catch (error) {
        console.error("❌ Lỗi lấy review theo phim:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// ==========================================
// API YÊU THÍCH PHIM
// ==========================================

// 1. Kiểm tra xem User đã thích phim này chưa (Lúc mở màn hình chi tiết)
app.get('/api/favorites/movie/check', async (req, res) => {
    const { user_id, movie_id } = req.query;
    try {
        const [rows] = await db.promise().query(
            'SELECT * FROM favorite_movies WHERE UserID = ? AND MovieID = ?', 
            [user_id, movie_id]
        );
        res.json({ isFavorite: rows.length > 0 });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 2. Thêm hoặc Xóa yêu thích phim (Lúc bấm nút Thích)
app.post('/api/favorites/movie/toggle', async (req, res) => {
    const { user_id, movie_id, is_favorite } = req.body;
    try {
        if (is_favorite) {
            // Nếu thích -> Insert vào bảng
            await db.promise().query(
                'INSERT IGNORE INTO favorite_movies (UserID, MovieID, CreatedAt) VALUES (?, ?, NOW())', 
                [user_id, movie_id]
            );
        } else {
            // Nếu bỏ thích -> Delete khỏi bảng
            await db.promise().query(
                'DELETE FROM favorite_movies WHERE UserID = ? AND MovieID = ?', 
                [user_id, movie_id]
            );
        }
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});
// ==========================================
// API: Lấy danh sách Phim Yêu Thích của User
// ==========================================
app.get('/api/user/favorites/:userId', async (req, res) => {
    const userId = req.params.userId;
    try {
        const sql = `
            SELECT 
                m.*, /* ✅ LẤY TOÀN BỘ THÔNG TIN PHIM ĐỂ TRUYỀN SANG TRANG CHI TIẾT */
                m.poster_path AS image, 
                m.vote_average AS rating, 
                DATE_FORMAT(fm.CreatedAt, '%d/%m/%Y') AS date_added
            FROM favorite_movies fm
            JOIN movies m ON fm.MovieID = m.id
            WHERE fm.UserID = ?
            ORDER BY fm.CreatedAt DESC
        `;
        const [results] = await db.promise().query(sql, [userId]);
        res.json(results);
    } catch (error) {
        console.error("Lỗi lấy phim yêu thích:", error);
        res.status(500).json({ error: error.message });
    }
});
// ==========================================
// API YÊU THÍCH RẠP (FAVORITE CINEMAS)
// ==========================================

// 1. Kiểm tra xem User đã thích rạp này chưa
app.get('/api/favorites/cinema/check', async (req, res) => {
    const { user_id, cinema_id } = req.query;
    try {
        const [rows] = await db.promise().query(
            'SELECT * FROM favorite_cinemas WHERE UserID = ? AND CinemaID = ?', 
            [user_id, cinema_id]
        );
        res.json({ isFavorite: rows.length > 0 });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 2. Thêm hoặc Xóa yêu thích rạp
app.post('/api/favorites/cinema/toggle', async (req, res) => {
    const { user_id, cinema_id, is_favorite } = req.body;
    try {
        if (is_favorite) {
            await db.promise().query('INSERT IGNORE INTO favorite_cinemas (UserID, CinemaID, CreatedAt) VALUES (?, ?, NOW())', [user_id, cinema_id]);
        } else {
            await db.promise().query('DELETE FROM favorite_cinemas WHERE UserID = ? AND CinemaID = ?', [user_id, cinema_id]);
        }
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 3. Lấy danh sách rạp yêu thích của User
app.get('/api/user/favorites/cinemas/:userId', async (req, res) => {
    const userId = req.params.userId;
    try {
        const sql = `
            SELECT c.id, c.Name AS name, c.Address AS address, c.latitude, c.longitude
            FROM favorite_cinemas fc
            JOIN cinemas c ON fc.CinemaID = c.id
            WHERE fc.UserID = ?
            ORDER BY fc.CreatedAt DESC
        `;
        const [results] = await db.promise().query(sql, [userId]);
        res.json(results);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================
// API NHÓM PHIM (KHÔNG TẠO BẢNG MỚI)
// ==========================================

// 1. API: Đếm tổng số thành viên có IsGroupJoined = 1
app.get('/api/group/members', async (req, res) => {
    try {
        const [rows] = await db.promise().query('SELECT COUNT(*) as total FROM users WHERE IsGroupJoined = 1');
        res.json({ total: rows[0].total });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 2. API: LẤY DANH SÁCH BÀI VIẾT (ĐÃ THÊM CỘT TÌM CÁC CẢM XÚC THỰC TẾ)
// 2. API: LẤY DANH SÁCH BÀI VIẾT (ĐÃ THÊM FULL DATA PHIM ĐỂ FLUTTER DÙNG)
app.get('/api/group/posts', async (req, res) => {
    const { user_id } = req.query; 
    try {
        const query = `
            SELECT p.PostID, p.Content, p.Type, p.CreatedAt, p.BgColor, p.UserID as PostUserID, p.Status, p.PostImages,
                   u.Username, u.Avatar, 
                   
                   COALESCE((
                       SELECT r.RoleName 
                       FROM userroles ur 
                       JOIN roles r ON ur.RoleID = r.RoleID 
                       WHERE ur.UserID = p.UserID 
                       LIMIT 1
                   ), 'user') AS Role,
                   
                   COALESCE(m.id, tm.id) AS MovieID, 
                   COALESCE(m.title, tm.title) AS MovieTitle, 
                   COALESCE(m.poster_path, tm.poster_path) AS MovieImage, 
                   COALESCE(m.genres, tm.genres) AS MovieGenres,
                   
                   -- ✅ ĐÃ BỔ SUNG 4 DÒNG NÀY ĐỂ TRUYỀN CHO FLUTTER
                   COALESCE(m.overview, tm.overview) AS MovieOverview,
                   COALESCE(m.vote_average, tm.vote_average) AS MovieVoteAverage,
                   COALESCE(m.backdrop_path, tm.backdrop_path) AS MovieBackdrop,
                   COALESCE(m.language, tm.language) AS MovieLanguage,
                   
                   tt.Price AS TransferPrice,
                   c.Name AS CinemaName,
                   c.Address AS CinemaAddress,
                   r.Name AS RoomName,
                   DATE_FORMAT(st.StartTime, '%H:%i - %d/%m/%Y') AS ShowtimeDate,
                   
                   (SELECT GROUP_CONCAT(s2.SeatNumber SEPARATOR ', ') 
                    FROM bookingseats bs2 JOIN seats s2 ON bs2.SeatID = s2.SeatID 
                    WHERE bs2.BookingID = b.BookingID) AS TransferSeats,
                    
                   (SELECT JSON_ARRAYAGG(JSON_OBJECT('name', f.Name, 'qty', bf.Quantity, 'image', IFNULL(f.ImageURL, ''))) 
                    FROM bookingfoods bf JOIN foods f ON bf.FoodID = f.FoodID 
                    WHERE bf.BookingID = b.BookingID) AS TransferFoods,

                   (SELECT COUNT(*) FROM post_likes WHERE PostID = p.PostID) as total_likes,
                   (SELECT COUNT(*) FROM comments WHERE PostID = p.PostID) as total_comments,
                   (SELECT ReactionType FROM post_likes WHERE PostID = p.PostID AND UserID = ?) as user_reaction,
                   
                   (SELECT GROUP_CONCAT(DISTINCT ReactionType) FROM post_likes WHERE PostID = p.PostID) as top_reactions
            FROM posts p
            JOIN users u ON p.UserID = u.UserID
            LEFT JOIN movies m ON p.TaggedMovieID = m.id
            LEFT JOIN tickettransfers tt ON p.PostID = tt.TransferID
            LEFT JOIN bookingseats bs_main ON tt.BookingSeatID = bs_main.BookingSeatID
            LEFT JOIN bookings b ON bs_main.BookingID = b.BookingID
            LEFT JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            LEFT JOIN rooms r ON st.RoomID = r.RoomID
            LEFT JOIN cinemas c ON r.CinemaID = c.id
            LEFT JOIN movies tm ON st.MovieID = tm.id
            WHERE p.Status = 1 OR (p.Status = 0 AND p.UserID = ?) 
            ORDER BY p.CreatedAt DESC
        `;
        const [posts] = await db.promise().query(query, [user_id, user_id]);
        res.json(posts);
    } catch (error) {
        console.error("Lỗi lấy bài viết:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// 3. API: Kiểm tra xem User này đã tham gia nhóm chưa
app.get('/api/group/check-join', async (req, res) => {
    const { user_id } = req.query;
    try {
        const [rows] = await db.promise().query('SELECT IsGroupJoined FROM users WHERE UserID = ?', [user_id]);
        if (rows.length > 0) {
            res.json({ isJoined: rows[0].IsGroupJoined === 1 });
        } else {
            res.json({ isJoined: false });
        }
    } catch (error) {
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 4. API: Cập nhật trạng thái tham gia (UPDATE trực tiếp vào bảng users)
app.post('/api/group/toggle-join', async (req, res) => {
    const { user_id, is_joined } = req.body;
    const status = is_joined ? 1 : 0;
    try {
        // Cập nhật cột IsGroupJoined của user
        await db.promise().query('UPDATE users SET IsGroupJoined = ? WHERE UserID = ?', [status, user_id]);
        
        // Đếm lại tổng số người đã vào nhóm để trả về cho Flutter gán lên UI
        const [rows] = await db.promise().query('SELECT COUNT(*) as total FROM users WHERE IsGroupJoined = 1');
        res.json({ success: true, total: rows[0].total });
    } catch (error) {
        console.error("Lỗi toggle join:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// ==========================================
// 5. API: ĐĂNG BÀI VIẾT MỚI (Đã gỡ bỏ duyệt bài & Đổi trạng thái vé sẵn sàng)
// ==========================================
app.post('/api/group/posts', upload.array('images', 5), async (req, res) => {
    const { user_id, content, type, bg_color, movie_id, price, booking_seat_id } = req.body; 
    
    // ✅ NÂNG CẤP 1: Dù là bài bình thường hay nhượng vé thì status đều là 1 (Công khai ngay lập tức)
    const status = 1; 

    try {
        // Xử lý mảng hình ảnh tải lên từ req.files
        let finalImages = [];
        if (req.files && req.files.length > 0) {
            finalImages = req.files.map(file => file.filename);
        }
        const postImagesJson = JSON.stringify(finalImages);

        // Xử lý an toàn movie_id
        const validMovieId = (movie_id && movie_id !== 'null' && movie_id !== '') ? parseInt(movie_id) : null;

        // Lưu bài viết vào bảng chính posts
        const [result] = await db.promise().query(
            'INSERT INTO posts (UserID, Content, Type, CreatedAt, Status, BgColor, TaggedMovieID, PostImages) VALUES (?, ?, ?, NOW(), ?, ?, ?, ?)',
            [user_id, content, type, status, bg_color || '', validMovieId, postImagesJson]
        );
        
        // Xử lý lưu vé nhượng nếu là bài chuyển nhượng
        if (type === 'transfer' && booking_seat_id) {
            const postId = result.insertId;

            // Tìm mã Ghế thật sự (BookingSeatID) nằm trong Hóa Đơn này
            const [seats] = await db.promise().query(
                'SELECT BookingSeatID FROM bookingseats WHERE BookingID = ? LIMIT 1', 
                [booking_seat_id]
            );

            // Nếu tìm thấy ghế của hóa đơn đó, tiến hành insert
            if (seats.length > 0) {
                const actualSeatId = seats[0].BookingSeatID;
                
                await db.promise().query(
                    'INSERT INTO tickettransfers (TransferID, BookingSeatID, SellerID, Price, Status) VALUES (?, ?, ?, ?, ?)',
                    // ✅ NÂNG CẤP 2: Đổi trạng thái từ 'Pending' thành 'Available' (Sẵn sàng bán, ai mua thì admin mới can thiệp)
                    [postId, actualSeatId, user_id, price, 'Available']
                );
            } else {
                console.log(`⚠️ Cảnh báo: Hóa đơn số ${booking_seat_id} không có dữ liệu ghế!`);
            }
        }
        res.json({ success: true, message: "Đăng bài thành công!" });
    } catch (error) {
        console.error("Lỗi đăng bài:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

app.get('/api/group/cleanup-transfers', async (req, res) => {
    try {
        // Đổi trạng thái bài viết thành 0 (Ẩn) nếu thời gian chiếu <= hiện tại + 60 phút
        const sql = `
            UPDATE posts p
            JOIN tickettransfers tt ON p.PostID = tt.TransferID
            JOIN bookingseats bs ON tt.BookingSeatID = bs.BookingSeatID
            JOIN bookings b ON bs.BookingID = b.BookingID
            JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            SET p.Status = 0, tt.Status = 'Expired'
            WHERE p.Type = 'transfer' 
              AND p.Status = 1
              AND st.StartTime <= DATE_ADD(NOW(), INTERVAL 60 MINUTE)
        `;
        const [result] = await db.promise().query(sql);
        res.json({ success: true, message: `Đã đóng ${result.affectedRows} bài nhượng vé quá hạn (trước giờ chiếu 60 phút).` });
    } catch (error) {
        console.error("Lỗi dọn bài nhượng vé:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 6. API: Xóa bài viết (Quyền tác giả)
app.delete('/api/group/posts/:id', async (req, res) => {
    const postId = req.params.id;
    const { user_id } = req.body;
    try {
        await db.promise().query('DELETE FROM posts WHERE PostID = ? AND UserID = ?', [postId, user_id]);
        res.json({ success: true, message: "Đã xóa bài viết" });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server" });
    }
});
// 7. API: Thả cảm xúc (Like, Tim, Haha...)
app.post('/api/group/posts/react', async (req, res) => {
    const { user_id, post_id, reaction_type } = req.body;
    try {
        // Kiểm tra xem đã thả cảm xúc chưa
        const [existing] = await db.promise().query('SELECT * FROM post_likes WHERE UserID = ? AND PostID = ?', [user_id, post_id]);
        
        if (existing.length > 0) {
            if (existing[0].ReactionType === reaction_type) {
                // Bấm lại đúng cảm xúc cũ -> Hủy thả cảm xúc
                await db.promise().query('DELETE FROM post_likes WHERE UserID = ? AND PostID = ?', [user_id, post_id]);
            } else {
                // Đổi sang cảm xúc khác
                await db.promise().query('UPDATE post_likes SET ReactionType = ? WHERE UserID = ? AND PostID = ?', [reaction_type, user_id, post_id]);
            }
        } else {
            // Chưa thả cảm xúc -> Thêm mới
            await db.promise().query('INSERT INTO post_likes (UserID, PostID, ReactionType) VALUES (?, ?, ?)', [user_id, post_id, reaction_type]);
        }
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server" });
    }
});


// =======================================================================
// ✅ API BỔ SUNG: LẤY CHI TIẾT ĐÚNG 1 BÀI POST (Để Flutter đồng bộ Like)
// =======================================================================
app.get('/api/group/posts/:postId', async (req, res) => {
    const postId = req.params.postId;
    const userId = req.query.user_id || 0; 
    
    try {
        const query = `
            SELECT p.PostID, p.Content, p.Type, p.CreatedAt, p.BgColor, p.UserID as PostUserID, p.Status, p.PostImages,
                   u.Username, u.Avatar, 
                   
                   COALESCE((
                       SELECT r.RoleName 
                       FROM userroles ur 
                       JOIN roles r ON ur.RoleID = r.RoleID 
                       WHERE ur.UserID = p.UserID 
                       LIMIT 1
                   ), 'user') AS Role,
                   
                   COALESCE(m.id, tm.id) AS MovieID, 
                   COALESCE(m.title, tm.title) AS MovieTitle, 
                   COALESCE(m.poster_path, tm.poster_path) AS MovieImage, 
                   COALESCE(m.genres, tm.genres) AS MovieGenres,

                   -- ✅ ĐÃ BỔ SUNG 4 DÒNG NÀY ĐỂ TRUYỀN CHO FLUTTER
                   COALESCE(m.overview, tm.overview) AS MovieOverview,
                   COALESCE(m.vote_average, tm.vote_average) AS MovieVoteAverage,
                   COALESCE(m.backdrop_path, tm.backdrop_path) AS MovieBackdrop,
                   COALESCE(m.language, tm.language) AS MovieLanguage,
                   
                   tt.Price AS TransferPrice,
                   c.Name AS CinemaName,
                   c.Address AS CinemaAddress,
                   r.Name AS RoomName,
                   DATE_FORMAT(st.StartTime, '%H:%i - %d/%m/%Y') AS ShowtimeDate,
                   
                   (SELECT GROUP_CONCAT(s2.SeatNumber SEPARATOR ', ') 
                    FROM bookingseats bs2 JOIN seats s2 ON bs2.SeatID = s2.SeatID 
                    WHERE bs2.BookingID = b.BookingID) AS TransferSeats,
                    
                   (SELECT JSON_ARRAYAGG(JSON_OBJECT('name', f.Name, 'qty', bf.Quantity, 'image', IFNULL(f.ImageURL, ''))) 
                    FROM bookingfoods bf JOIN foods f ON bf.FoodID = f.FoodID 
                    WHERE bf.BookingID = b.BookingID) AS TransferFoods,

                   (SELECT COUNT(*) FROM post_likes WHERE PostID = p.PostID) as total_likes,
                   (SELECT COUNT(*) FROM comments WHERE PostID = p.PostID) as total_comments,
                   (SELECT ReactionType FROM post_likes WHERE PostID = p.PostID AND UserID = ?) as user_reaction,
                   
                   -- Lấy danh sách cảm xúc chuẩn xác từ DB (không bị dính khoảng trắng)
                   (SELECT GROUP_CONCAT(DISTINCT ReactionType) FROM post_likes WHERE PostID = p.PostID) as top_reactions
            FROM posts p
            JOIN users u ON p.UserID = u.UserID
            LEFT JOIN movies m ON p.TaggedMovieID = m.id
            LEFT JOIN tickettransfers tt ON p.PostID = tt.TransferID
            LEFT JOIN bookingseats bs_main ON tt.BookingSeatID = bs_main.BookingSeatID
            LEFT JOIN bookings b ON bs_main.BookingID = b.BookingID
            LEFT JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            LEFT JOIN rooms r ON st.RoomID = r.RoomID
            LEFT JOIN cinemas c ON r.CinemaID = c.id
            LEFT JOIN movies tm ON st.MovieID = tm.id
            WHERE p.PostID = ?
            LIMIT 1
        `;
        
        const [posts] = await db.promise().query(query, [userId, postId]);
        
        if (posts.length === 0) {
            return res.status(404).json({ error: "Không tìm thấy bài viết!" });
        }
        
        res.json(posts[0]);
    } catch (error) {
        console.error("Lỗi lấy chi tiết bài viết:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// Lấy danh sách bình luận của 1 bài viết
// ==========================================
// 1. API: LẤY DANH SÁCH BÌNH LUẬN (Đã thêm ParentID để lồng nhau)
// ==========================================
app.get('/api/group/posts/:postId/comments', async (req, res) => {
    const postId = req.params.postId;
    const userId = req.query.user_id || 0; 
    try {
        const sql = `
            SELECT c.CommentID, c.Content, c.CreatedAt, c.ParentID, c.ImageURL, 
                   u.Username, u.Avatar, u.UserID,
                   (SELECT COUNT(*) FROM comment_likes WHERE CommentID = c.CommentID) as likeCount,
                   (SELECT ReactionType FROM comment_likes WHERE CommentID = c.CommentID AND UserID = ?) as userReaction,
                   (SELECT GROUP_CONCAT(DISTINCT ReactionType) FROM comment_likes WHERE CommentID = c.CommentID) as topReactions
            FROM comments c
            JOIN users u ON c.UserID = u.UserID
            WHERE c.PostID = ?
            ORDER BY c.CreatedAt ASC
        `;
        const [comments] = await db.promise().query(sql, [userId, postId]);
        res.json(comments);
    } catch (error) {
        console.error("Lỗi lấy bình luận:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// ==========================================
// 2. API: ĐĂNG BÌNH LUẬN KÈM ẢNH (Dùng upload.single('image'))
// ==========================================
app.put('/api/group/comments/:commentId', upload.single('image'), async (req, res) => {
    const commentId = req.params.commentId;
    const { user_id, content, keep_old_image } = req.body;
    const imageUrl = req.file ? req.file.filename : null;

    try {
        if (imageUrl) {
            await db.promise().query(
                'UPDATE comments SET Content = ?, ImageURL = ? WHERE CommentID = ? AND UserID = ?',
                [content, imageUrl, commentId, user_id]
            );
        } else if (keep_old_image === 'false') {
            await db.promise().query(
                'UPDATE comments SET Content = ?, ImageURL = NULL WHERE CommentID = ? AND UserID = ?',
                [content, commentId, user_id]
            );
        } else {
            await db.promise().query(
                'UPDATE comments SET Content = ? WHERE CommentID = ? AND UserID = ?',
                [content, commentId, user_id]
            );
        }
        res.json({ success: true, message: "Đã cập nhật bình luận!" });
    } catch (error) {
        console.error("Lỗi sửa bình luận:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// ==========================================
// API: SỬA BÌNH LUẬN (Chỉ chủ nhân mới được sửa)
// ==========================================
app.put('/api/group/comments/:commentId', async (req, res) => {
    const commentId = req.params.commentId;
    const { user_id, content } = req.body;
    try {
        await db.promise().query(
            'UPDATE comments SET Content = ? WHERE CommentID = ? AND UserID = ?',
            [content, commentId, user_id]
        );
        res.json({ success: true, message: "Đã cập nhật bình luận!" });
    } catch (error) {
        console.error("Lỗi sửa bình luận:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// ==========================================
// API: XÓA BÌNH LUẬN (Xóa luôn cả bình luận con nếu có)
// ==========================================
app.delete('/api/group/comments/:commentId', async (req, res) => {
    const commentId = req.params.commentId;
    const { user_id } = req.body;
    try {
        const [check] = await db.promise().query('SELECT UserID FROM comments WHERE CommentID = ?', [commentId]);
        if (check.length === 0 || check[0].UserID.toString() !== user_id.toString()) {
            return res.status(403).json({ error: "Không có quyền xóa!" });
        }
        await db.promise().query(
            'DELETE FROM comments WHERE CommentID = ? OR ParentID = ?', 
            [commentId, commentId]
        );
        res.json({ success: true, message: "Đã xóa bình luận tận gốc!" });
    } catch (error) {
        console.error("Lỗi xóa bình luận:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// Đăng bình luận mới
app.post('/api/group/posts/:postId/comments', upload.single('image'), async (req, res) => {
    const postId = req.params.postId;
    const { user_id, content, parent_id } = req.body; 
    const imageUrl = req.file ? req.file.filename : null;

    try {
        await db.promise().query(
            'INSERT INTO comments (PostID, UserID, Content, ParentID, CreatedAt, ImageURL) VALUES (?, ?, ?, ?, NOW(), ?)', 
            [postId, user_id, content || '', parent_id || null, imageUrl]
        );
        res.json({ success: true, message: "Đăng bình luận thành công!" });
    } catch (error) {
        console.error("Lỗi đăng bình luận:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

app.post('/api/group/comments/react', async (req, res) => {
    const { user_id, comment_id, reaction_type } = req.body;
    try {
        const [existing] = await db.promise().query('SELECT * FROM comment_likes WHERE CommentID = ? AND UserID = ?', [comment_id, user_id]);
        
        if (existing.length > 0) {
            if (existing[0].ReactionType === reaction_type) {
                await db.promise().query('DELETE FROM comment_likes WHERE CommentID = ? AND UserID = ?', [comment_id, user_id]);
            } else {
                await db.promise().query('UPDATE comment_likes SET ReactionType = ? WHERE CommentID = ? AND UserID = ?', [reaction_type, comment_id, user_id]);
            }
        } else {
            await db.promise().query('INSERT INTO comment_likes (CommentID, UserID, ReactionType) VALUES (?, ?, ?)', [comment_id, user_id, reaction_type]);
        }
        res.json({ success: true });
    } catch (error) {
        console.error("Lỗi thả cảm xúc bình luận:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 6. API: SỬA BÀI VIẾT & CẬP NHẬT GIÁ VÉ + ĐA HÌNH ẢNH (TỐI ĐA 5 FILE)
app.put('/api/group/posts/:id', upload.array('images', 5), async (req, res) => {
    const postId = req.params.id;
    const { user_id, content, price, bg_color, movie_id, old_images } = req.body;
    
    try {
        // Giải mã mảng ảnh cũ người dùng giữ lại từ Flutter gửi lên
        let finalImages = [];
        if (old_images) {
            finalImages = JSON.parse(old_images);
        }

        // Nếu có ảnh mới upload từ máy lên, gộp tên ảnh mới vào mảng
        if (req.files && req.files.length > 0) {
            const newImageNames = req.files.map(file => file.filename);
            finalImages = [...finalImages, ...newImageNames];
        }

        // Gói mảng ảnh thành chuỗi JSON để nạp vào 1 cột trong CSDL
        const postImagesJson = JSON.stringify(finalImages.slice(0, 5)); // Đảm bảo luôn chặn lấy tối đa 5 ảnh

        // Cập nhật bảng postsหลัก
        await db.promise().query(
            'UPDATE posts SET Content = ?, BgColor = ?, TaggedMovieID = ?, PostImages = ? WHERE PostID = ? AND UserID = ?', 
            [content, bg_color || '', movie_id ? parseInt(movie_id) : null, postImagesJson, postId, user_id]
        );
        
        // Nếu là bài nhượng vé -> cập nhật thêm giá bán trong bảng tickettransfers
        if (price && parseInt(price) > 0) {
            await db.promise().query(
                'UPDATE tickettransfers SET Price = ? WHERE TransferID = ? AND SellerID = ?', 
                [price, postId, user_id]
            );
        }

        res.json({ success: true, message: "Đã cập nhật bài viết và hình ảnh thành công!" });
    } catch (error) {
        console.error("Lỗi sửa bài viết:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// API: YÊU CẦU HOÀN TIỀN
app.post('/api/user/refund', (req, res) => {
    const { bookingId, reason } = req.body;
    
    // ✅ ĐÃ SỬA LỖI: Bỏ cột PaymentID ra khỏi lệnh SELECT vì bảng bookings không có cột này
    const getBookingSql = `SELECT TotalAmount, Status FROM bookings WHERE BookingID = ?`;
    
    db.query(getBookingSql, [bookingId], (err, results) => {
        if (err) return res.status(500).json({error: err.message});
        if (results.length === 0) return res.status(404).json({error: "Không tìm thấy vé"});
        
        // Kiểm tra nếu đã hoàn rồi thì chặn
        if (results[0].Status === 'Refund Pending' || results[0].Status === 'Refunded') {
            return res.status(400).json({error: "Vé này đã được yêu cầu hoàn tiền trước đó!"});
        }

        const amount = results[0].TotalAmount;
        const paymentId = null; // ✅ Gán mặc định là null để truyền vào bảng refunds
        
        // Insert vào bảng refunds theo cấu trúc của bạn
        const insertRefundSql = `
            INSERT INTO refunds (BookingID, PaymentID, Amount, Reason, Status, RefundStatus, CreatedAt) 
            VALUES (?, ?, ?, ?, 'Pending', 'pending', NOW())
        `;
        
        db.query(insertRefundSql, [bookingId, paymentId, amount, reason], (err2, result2) => {
            if (err2) return res.status(500).json({error: err2.message});
            
            // Cập nhật lại status của bookings thành Refund Pending
            db.query(`UPDATE bookings SET Status = 'Refund Pending' WHERE BookingID = ?`, [bookingId]);
            
            res.json({ success: true, message: "Gửi yêu cầu hoàn tiền thành công!" });
        });
    });
});

// =====================================================================
// 1. API LẤY DANH SÁCH VOUCHER (Hiển thị ở Trang Chủ & Danh sách)
// =====================================================================
app.get('/api/vouchers', (req, res) => {
    // Chỉ lấy các voucher còn số lượng > 0 và Hạn sử dụng (ExpiredAt) lớn hơn ngày hiện tại
    const sql = `
        SELECT VoucherID, Code, DiscountPercent, ExpiredAt, Quantity 
        FROM vouchers 
        WHERE Quantity > 0 AND ExpiredAt > NOW()
        ORDER BY DiscountPercent DESC
    `;
    
    db.query(sql, (err, results) => {
        if (err) {
            console.error('Lỗi truy vấn vouchers:', err);
            return res.status(500).json({ error: 'Lỗi server khi lấy dữ liệu voucher' });
        }
        res.status(200).json(results);
    });
});

// =====================================================================
// 2. API LƯU VOUCHER VÀO VÍ NGƯỜI DÙNG (Khi bấm nút "Lưu")
// =====================================================================
// Lưu ý: Cần tạo thêm 1 bảng 'user_vouchers' trong MySQL gồm (UserID, VoucherID, Status)
app.post('/api/vouchers/save', (req, res) => {
    const { userId, voucherId } = req.body;
    
    if (!userId || !voucherId) {
        return res.status(400).json({ error: 'Thiếu thông tin người dùng hoặc voucher' });
    }

    // Bước 1: Kiểm tra xem user này đã lưu mã này chưa
    const checkSql = 'SELECT * FROM uservouchers WHERE UserID = ? AND VoucherID = ?';
    db.query(checkSql, [userId, voucherId], (err, results) => {
        if (err) return res.status(500).json({ error: 'Lỗi kiểm tra voucher' });
        
        if (results.length > 0) {
            return res.status(400).json({ message: 'Bạn đã lưu voucher này rồi!' });
        }

        // Bước 2: Thêm vào ví với Status = 0 (Chưa sử dụng)
        const insertSql = 'INSERT INTO uservouchers (UserID, VoucherID, Status) VALUES (?, ?, 0)';
        db.query(insertSql, [userId, voucherId], (insertErr) => {
            if (insertErr) return res.status(500).json({ error: 'Lỗi khi lưu voucher vào ví' });
            
            // Bước 3: Trừ đi 1 số lượng trong kho vouchers gốc
            const updateSql = 'UPDATE vouchers SET Quantity = Quantity - 1 WHERE VoucherID = ? AND Quantity > 0';
            db.query(updateSql, [voucherId], (updateErr) => {
                if (updateErr) console.error('Lỗi cập nhật số lượng voucher:', updateErr);
                
                res.status(200).json({ message: 'Lưu voucher thành công!' });
            });
        });
    });
});
// =====================================================================
// 3. API LẤY DANH SÁCH VOUCHER MÀ USER ĐÃ LƯU (Lấy cả Đã dùng & Chưa dùng)
// =====================================================================
// =====================================================================
// 3. API LẤY DANH SÁCH VOUCHER MÀ USER ĐÃ LƯU 
// =====================================================================
app.get('/api/vouchers/user/:userId', (req, res) => {
    const userId = req.params.userId;
    
    // ✅ SỬA LẠI: Select chính xác cột 'Used' từ bảng uservouchers của bạn
    const sql = `
        SELECT 
            v.VoucherID, 
            v.Code, 
            v.DiscountPercent, 
            v.ExpiredAt, 
            uv.Used 
        FROM uservouchers uv
        JOIN vouchers v ON uv.VoucherID = v.VoucherID
        WHERE uv.UserID = ?
        ORDER BY v.DiscountPercent DESC
    `;
    
    db.query(sql, [userId], (err, results) => {
        if (err) {
            console.error('Lỗi SQL lấy ví voucher:', err);
            return res.status(500).json({ error: 'Lỗi server' });
        }
        res.status(200).json(results);
    });
});

// =====================================================================
// 4. API ĐÁNH DẤU VOUCHER ĐÃ SỬ DỤNG (Gọi sau khi thanh toán thành công)
// =====================================================================
app.post('/api/vouchers/mark-used', (req, res) => {
    const { userId, voucherId } = req.body;
    
    if (!userId || !voucherId) {
        return res.status(400).json({ error: 'Thiếu thông tin' });
    }

    // Cập nhật cả Used = 1 và Status = 1 để chuyển mã sang tab "Đã sử dụng"
    const sql = 'UPDATE uservouchers SET Used = 1, Status = 1 WHERE UserID = ? AND VoucherID = ?';
    
    db.query(sql, [userId, voucherId], (err, result) => {
        if (err) {
            console.error('Lỗi cập nhật trạng thái voucher:', err);
            return res.status(500).json({ error: 'Lỗi server' });
        }
        res.status(200).json({ message: 'Đã cập nhật voucher thành Đã sử dụng!' });
    });
});

// ==========================================
// 5. KHỞI ĐỘNG SERVER
// ==========================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server backend đang chạy tại port: ${PORT}`);
});