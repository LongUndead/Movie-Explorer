const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
require ('dotenv').config();
const axios = require('axios');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const path = require('path');
const cron = require('node-cron');
const NodeCache = require('node-cache');
const nodemailer = require('nodemailer');
const otpCache = new NodeCache({ stdTTL: 300, checkperiod: 60 });

const http = require('http');
const { Server } = require('socket.io');

const app = express();
app.use(express.json());
app.use(cors());

// ✅ BỌC EXPRESS VÀO HTTP SERVER VÀ KHỞI TẠO SOCKET.IO
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});
// Đưa biến io vào app để nếu cần dùng trong các route khác (như đặt vé xong) thì gọi được
app.set('io', io)

const db = require('./db');

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

const avatarStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'public/avatars/'); // Lưu file ảnh vào thư mục avatars
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'avatar-' + uniqueSuffix + path.extname(file.originalname)); 
    }
});
const uploadAvatar = multer({ storage: avatarStorage });
// Đảm bảo Node.js mở thư mục này công khai để Flutter load được Link Network Image
app.use('/uploads', express.static(path.join(__dirname, 'public/uploads')));
app.use('/avatars', express.static(path.join(__dirname, 'public/avatars')));
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

// ==========================================
// API: CẬP NHẬT THÔNG TIN TÀI KHOẢN (ĐÃ CHUẨN HÓA)
// ==========================================
// 🚀 Đổi `upload` thành `uploadAvatar` ở đây:
app.put('/api/user/profile/update', uploadAvatar.single('avatar'), async (req, res) => {
    const { user_id, name, phone } = req.body;
    const file = req.file; // Ảnh Mobile gửi lên nằm ở đây

    try {
        let sql;
        let params;
        let newAvatarUrl = null;

        // Nếu user CÓ ĐỔI ẢNH (file không bị null)
        if (file) {
            // 🚀 BẮT BUỘC PHẢI THÊM CHỮ 'avatars/' PHÍA TRƯỚC ĐỂ LƯU VÀO MYSQL
            newAvatarUrl = 'avatars/' + file.filename; 
            
            sql = 'UPDATE users SET Username = ?, Phone = ?, Avatar = ? WHERE UserID = ?';
            params = [name, phone, newAvatarUrl, user_id];
        } 
        // Nếu user CHỈ SỬA TÊN/SỐ ĐIỆN THOẠI (không chọn ảnh)
        else {
            sql = 'UPDATE users SET Username = ?, Phone = ? WHERE UserID = ?';
            params = [name, phone, user_id];
        }

        await db.promise().query(sql, params);

        res.json({ 
            success: true, 
            message: "Cập nhật hồ sơ thành công!",
            newAvatar: newAvatarUrl // Gửi trả link (VD: avatars/avatar-123.jpg) về cho Mobile
        });

    } catch (error) {
        console.error("Lỗi cập nhật profile:", error);
        res.status(500).json({ success: false, message: "Lỗi hệ thống" });
    }
});
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
// ==========================================
// 3. CÁC API LẤY DỮ LIỆU (GET) - CHO FLUTTER APP
// ==========================================

// Lấy danh sách phim
app.get('/api/movies', (req, res) => {
    // ✅ ĐÃ SỬA: Thêm "WHERE IsDeleted = 0" để Mobile CHỈ lấy những phim đang được Hiện
    db.query("SELECT * FROM movies WHERE IsDeleted = 0 ORDER BY release_date DESC", (err, results) => {
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
    const date = req.query.date;

    if (!movieId || !cinemaId || !date) {
        return res.status(400).json({ error: "Thiếu tham số (movie_id, cinema_id, date)!" });
    }

    const sql = `
        SELECT 
            s.ShowtimeID, 
            DATE_FORMAT(s.StartTime, '%Y-%m-%dT%H:%i:00') AS StartTime, 
            DATE_FORMAT(s.EndTime, '%Y-%m-%dT%H:%i:00') AS EndTime, 
            s.Price, s.cinetour AS IsCinetour,
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
          AND s.StartTime > NOW()
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

    const sql = `
        SELECT 
            s.ShowtimeID, 
            DATE_FORMAT(s.StartTime, '%Y-%m-%dT%H:%i:00') AS StartTime, 
            DATE_FORMAT(s.EndTime, '%Y-%m-%dT%H:%i:00') AS EndTime, 
            s.Price, s.cinetour AS IsCinetour, s.movie_format,
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
          AND s.StartTime > NOW()
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
        // =================================================================
        // ✅ ĐÃ THÊM CHỮ "IGNORE": Chống sập Server khi Double Click
        // Nếu ghế đã tồn tại trong bảng seatholds, nó sẽ nhẹ nhàng bỏ qua!
        // =================================================================
        const sql = `
            INSERT IGNORE INTO seatholds (UserID, ShowtimeID, SeatID, ExpiredAt, Status) 
            VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE), 'holding')
        `;
        await db.promise().query(sql, [userId, showtimeId, seatId]);
        
        res.json({ success: true, message: "Yêu cầu khóa ghế đã được xử lý" });
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

// ==========================================
// 4. API NGHIỆP VỤ (POST)
// ==========================================

// API Đăng nhập (Phiên bản BỌC THÉP CHỐNG XUYÊN THỦNG)
app.post('/api/login', async (req, res) => {
    const { email, password } = req.body;

    try {
        // =======================================================
        // 1. CHỐT CHẶN BẢO TRÌ TỪ CẤU HÌNH HỆ THỐNG
        // =======================================================
        const [configRows] = await db.promise().query(
            "SELECT ConfigKey, ConfigValue FROM systemconfigs WHERE ConfigKey IN ('isMaintenanceMode', 'maintenanceEndTime', 'maintenanceMessage')"
        );
        
        let isMaintenanceMode = false;
        let maintenanceEndTime = null;
        let maintenanceMessage = 'Hệ thống đang bảo trì định kỳ. Vui lòng quay lại sau!';

        // Bóc tách dữ liệu cấu hình
        for (let row of configRows) {
            const val = String(row.ConfigValue).trim(); // Ép kiểu chuỗi cho chắc ăn
            
            if (row.ConfigKey === 'isMaintenanceMode') {
                // Chấp nhận số 1, chữ '1', chữ 'true'
                isMaintenanceMode = (val === '1' || val.toLowerCase() === 'true');
            }
            if (row.ConfigKey === 'maintenanceEndTime' && val !== '' && val !== 'null') {
                maintenanceEndTime = new Date(val);
            }
            if (row.ConfigKey === 'maintenanceMessage' && val !== '') {
                maintenanceMessage = val;
            }
        }

        const now = new Date();

        // 🚀 BẬT MÁY NGHE LÉN ĐỂ XEM NODE.JS ĐANG NGHĨ GÌ
        console.log("\n=== 🚦 KIỂM TRA TRẠNG THÁI BẢO TRÌ ===");
        console.log("👉 Công tắc đang bật?:", isMaintenanceMode);
        console.log("👉 Giờ chót bảo trì:", maintenanceEndTime);
        console.log("👉 Giờ hiện tại:", now);

        if (isMaintenanceMode) {
            let isStillLocked = true; // Mặc định là đang khóa
            
            // Nếu có cài đặt giờ chót, kiểm tra xem đã qua giờ chưa
            if (maintenanceEndTime instanceof Date && !isNaN(maintenanceEndTime.getTime())) {
                // Nếu giờ hiện tại >= giờ chót -> Hết bảo trì!
                if (now.getTime() >= maintenanceEndTime.getTime()) {
                    isStillLocked = false; 
                }
            }

            console.log("👉 Lệnh chốt chặn cuối cùng:", isStillLocked ? "🛑 CHẶN KHÁCH!" : "✅ CHO QUA!");
            console.log("=====================================\n");

            if (isStillLocked) {
                // Đổi thành mã 401 để App Flutter bắt lỗi và văng Popup giống như "Sai mật khẩu"
                return res.status(401).json({ 
                    error: maintenanceMessage,
                    isMaintenance: true
                });
            }
        } else {
            console.log("👉 Lệnh chốt chặn cuối cùng: ✅ CHO QUA (Không bật)!");
            console.log("=====================================\n");
        }

        // =======================================================
        // 2. LOGIC ĐĂNG NHẬP BÌNH THƯỜNG
        // =======================================================
        const sql = "SELECT UserID, Username, Email, Phone, Avatar, PasswordHash FROM users WHERE Email = ?";
        
        db.query(sql, [email], async (err, results) => {
            if (err) return res.status(500).json({ error: err.message });
            
            if (results.length === 0) {
                return res.status(401).json({ error: "Email không tồn tại" });
            }

            const user = results[0];

            try {
                const isMatch = await bcrypt.compare(password, user.PasswordHash);

                if (isMatch) {
                    delete user.PasswordHash;
                    res.json({ message: "Đăng nhập thành công", user: user });
                } else {
                    res.status(401).json({ error: "Sai mật khẩu" });
                }
            } catch (error) {
                console.error("Lỗi giải mã:", error);
                res.status(500).json({ error: "Lỗi hệ thống khi xác thực" });
            }
        });

    } catch (error) {
        console.error("Lỗi server kiểm tra bảo trì:", error);
        res.status(500).json({ error: "Lỗi hệ thống máy chủ!" });
    }
});

// ==========================================
// API 1: GỬI OTP XÁC NHẬN ĐĂNG KÝ
// ==========================================
app.post('/api/send-register-otp', async (req, res) => {
    const { email } = req.body;

    if (!email) {
        return res.status(400).json({ error: "Vui lòng cung cấp Email!" });
    }

    try {
        // 1. Kiểm tra xem Email đã tồn tại trong hệ thống chưa (Lấy từ code gốc của ông)
        const [existingUsers] = await db.promise().query('SELECT UserID FROM users WHERE Email = ?', [email]);
        
        if (existingUsers.length > 0) {
            return res.status(400).json({ error: "Email này đã được sử dụng. Vui lòng chọn Email khác!" });
        }

        // 2. Tạo mã OTP ngẫu nhiên 6 số
        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        // 3. Lưu vào RAM (Thêm chữ REG_ để phân biệt với OTP quên pass), sống 5 phút
        otpCache.set("REG_" + email, otp);
        console.log(`[CACHE] Đã lưu OTP ĐĂNG KÝ ${otp} cho ${email}`);

        // 4. Lấy cấu hình SMTP từ database
        const [configRows] = await db.promise().query(
            "SELECT ConfigKey, ConfigValue FROM systemconfigs WHERE ConfigKey IN ('smtpHost', 'smtpPort', 'smtpUser', 'smtpPass')"
        );
        let smtp = {};
        configRows.forEach(row => smtp[row.ConfigKey] = row.ConfigValue);

        if (!smtp.smtpHost || !smtp.smtpUser || !smtp.smtpPass) {
            return res.status(500).json({ error: "Hệ thống chưa cấu hình Mail Server!" });
        }

        // 5. Cấu hình cục phát và gửi Mail
        const transporter = nodemailer.createTransport({
            host: smtp.smtpHost,
            port: Number(smtp.smtpPort),
            secure: Number(smtp.smtpPort) === 465,
            auth: { user: smtp.smtpUser, pass: smtp.smtpPass }
        });

        await transporter.sendMail({
            from: `"Cinema Tickets" <${smtp.smtpUser}>`,
            to: email,
            subject: "Mã xác thực tài khoản mới",
            html: `
                <div style="font-family: Arial, sans-serif; padding: 20px; text-align: center;">
                    <h2>Chào mừng bạn đến với CinemaTickets!</h2>
                    <p>Mã xác thực đăng ký tài khoản của bạn là:</p>
                    <h1 style="color: #2E7D32; font-size: 40px; letter-spacing: 5px; background: #f4f4f4; padding: 10px; border-radius: 8px; display: inline-block;">${otp}</h1>
                    <p style="color: red;">* Mã này chỉ có hiệu lực trong vòng 5 phút.</p>
                </div>
            `
        });

        res.status(200).json({ success: true, message: "Đã gửi mã xác nhận đến email!" });

    } catch (error) {
        console.error("❌ Lỗi gửi OTP đăng ký:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi gửi email!" });
    }
});
// ==========================================
// API 2: ĐĂNG KÝ TÀI KHOẢN MỚI (CÓ CHECK OTP)
// ==========================================
app.post('/api/register', async (req, res) => {
    // 🚀 Nhận thêm biến otp từ Flutter gửi lên
    const { username, email, phone, password, otp } = req.body;

    // 1. Kiểm tra dữ liệu đầu vào
    if (!username || !email || !password || !otp) {
        return res.status(400).json({ error: "Vui lòng nhập đầy đủ Tên, Email, Mật khẩu và Mã OTP!" });
    }

    try {
        // 2. 🚀 KIỂM TRA MÃ OTP TRONG RAM
        const cachedOtp = otpCache.get("REG_" + email);
        
        if (!cachedOtp) {
            return res.status(400).json({ error: "Mã OTP đã hết hạn hoặc không tồn tại. Vui lòng gửi lại!" });
        }
        if (cachedOtp !== otp.toString()) {
            return res.status(400).json({ error: "Mã OTP không chính xác!" });
        }

        // 3. OTP Đúng -> Lập tức xóa khỏi RAM để không bị dùng lại
        otpCache.del("REG_" + email);

        // 4. Mã hóa mật khẩu (Giữ nguyên băm 12 vòng cực kỳ bảo mật của ông)
        const hashedPassword = await bcrypt.hash(password, 12);

        // 5. Lưu vào Database (Giữ nguyên 100% câu SQL gốc của ông)
        const sql = 'INSERT INTO users (Username, Email, Phone, PasswordHash) VALUES (?, ?, ?, ?)';
        await db.promise().query(sql, [username, email, phone || null, hashedPassword]);

        res.status(200).json({ success: true, message: "Đăng ký tài khoản thành công!" });

    } catch (error) {
        console.error("❌ Lỗi khi đăng ký tài khoản:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi đăng ký. Vui lòng thử lại sau!" });
    }
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
    
    // ✅ ĐÃ SỬA: Thêm "AND Status = 'Paid'" để bỏ qua các đơn Pending hoặc Cancelled
    const sql = "SELECT SUM(TotalAmount) AS totalSpent FROM bookings WHERE UserID = ? AND Status = 'Paid'";
    
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
            m.TrailerURL AS TrailerURL,
            st.movie_format AS format, -- 🚀 ĐÃ LÔI CỘT ĐỊNH DẠNG TỪ BẢNG SHOWTIMES RA NÈ
            
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
        
        -- 🚀 ĐÃ SỬA: Lấy cả vé Đã thanh toán, Đang chờ hoàn và Đã hoàn tiền
        WHERE b.UserID = ? AND b.Status IN ('Paid', 'Refund Pending', 'Refunded')
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
            
            // 1. Đếm Phim đã xem (Dùng DISTINCT st.MovieID để loại bỏ trùng lặp phim)
            db.promise().query(
                `SELECT COUNT(DISTINCT st.MovieID) AS count 
                 FROM bookings b 
                 JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID 
                 WHERE b.UserID = ? AND st.StartTime < NOW() AND b.Status = 'Paid'`, 
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
            WHERE b.UserID = ? AND st.StartTime < NOW() AND b.Status = 'Paid'
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
    const files = req.files; // Mảng file ảnh từ Multer
    const status = 1; 

    // Mở Transaction để đảm bảo tính toàn vẹn (Ghi bảng posts XONG thì mới ghi bảng postimages)
    const connection = await db.promise().getConnection();
    try {
        await connection.beginTransaction();

        // 1. Lưu vào bảng POSTS (Lưu ý: Đã bỏ cột PostImages vì ta không dùng JSON nữa)
        const sqlInsertPost = `
            INSERT INTO posts (UserID, Content, Type, CreatedAt, Status, BgColor, TaggedMovieID) 
            VALUES (?, ?, ?, NOW(), ?, ?, ?)
        `;
        const [postResult] = await connection.query(sqlInsertPost, [
            user_id, content || '', type || 'normal', status, bg_color || '', 
            (movie_id && movie_id !== 'null' && movie_id !== '') ? parseInt(movie_id) : null
        ]);
        
        const postId = postResult.insertId;

        // 2. INSERT HÌNH ẢNH VÀO BẢNG POSTIMAGES (Tách rời từng ảnh)
        if (files && files.length > 0) {
            const sqlInsertImage = 'INSERT INTO postimages (PostID, ImageURL) VALUES (?, ?)';
            for (let file of files) {
                await connection.query(sqlInsertImage, [postId, file.filename]);
            }
        }

        // 3. Xử lý vé nhượng (Giữ nguyên logic cũ của con)
        if (type === 'transfer' && booking_seat_id) {
            const [seats] = await connection.query(
                'SELECT BookingSeatID FROM bookingseats WHERE BookingID = ? LIMIT 1', 
                [booking_seat_id]
            );

            if (seats.length > 0) {
                await connection.query(
                    'INSERT INTO tickettransfers (TransferID, BookingSeatID, SellerID, Price, Status) VALUES (?, ?, ?, ?, ?)',
                    [postId, seats[0].BookingSeatID, user_id, price, 'Available']
                );
            }
        }

        await connection.commit();
        res.json({ success: true, message: "Đăng bài thành công!" });

    } catch (error) {
        await connection.rollback(); 
        console.error("Lỗi đăng bài:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi lưu bài viết" });
    } finally {
        connection.release();
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
    // ✅ ĐÃ SỬA: Thêm MinOrderValue và MaxDiscountAmount vào câu lệnh SELECT
    const sql = `
        SELECT VoucherID, Code, DiscountPercent, ExpiredAt, Quantity, MinOrderValue, MaxDiscountAmount 
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
// 3. API LẤY DANH SÁCH VOUCHER MÀ USER ĐÃ LƯU 
// =====================================================================
app.get('/api/vouchers/user/:userId', (req, res) => {
    const userId = req.params.userId;
    
    // ✅ ĐÃ SỬA: Thêm v.MinOrderValue và v.MaxDiscountAmount để Flutter bắt được giá trị điều kiện đơn hàng
    const sql = `
        SELECT 
            v.VoucherID, 
            v.Code, 
            v.DiscountPercent, 
            v.ExpiredAt, 
            v.MinOrderValue, 
            v.MaxDiscountAmount, 
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

    const sql = 'UPDATE uservouchers SET Used = 1, Status = 1 WHERE UserID = ? AND VoucherID = ?';
    
    db.query(sql, [userId, voucherId], (err, result) => {
        if (err) {
            console.error('Lỗi cập nhật trạng thái voucher:', err);
            return res.status(500).json({ error: 'Lỗi server' });
        }
        res.status(200).json({ message: 'Đã cập nhật voucher thành Đã sử dụng!' });
    });
});

// =======================================================================
// API: BÁO CÁO BÀI VIẾT (REPORT POST)
// =======================================================================
app.post('/api/group/posts/report', async (req, res) => {
    const { post_id, reporter_id, reason } = req.body;

    try {
        // 1. Kiểm tra xem user này đã báo cáo bài này chưa (Chống spam)
        const [existingReport] = await db.promise().query(
            'SELECT * FROM post_reports WHERE PostID = ? AND ReporterID = ?',
            [post_id, reporter_id]
        );

        if (existingReport.length > 0) {
            return res.status(400).json({ success: false, message: "Bạn đã báo cáo bài viết này rồi!" });
        }

        // 2. Nếu chưa, tiến hành lưu báo cáo
        // (Status = 'Pending' nghĩa là chờ Admin duyệt)
        await db.promise().query(
            'INSERT INTO post_reports (PostID, ReporterID, Reason, CreatedAt, Status) VALUES (?, ?, ?, NOW(), ?)',
            [post_id, reporter_id, reason || 'Lý do khác', 'Pending']
        );

        res.json({ success: true, message: "Cảm ơn bạn! Báo cáo đã được gửi cho Quản trị viên." });
    } catch (error) {
        console.error("❌ Lỗi báo cáo bài viết:", error);
        res.status(500).json({ success: false, message: "Lỗi hệ thống khi báo cáo" });
    }
});

// =========================================================================
// 🚀 HỆ THỐNG CRONJOB CHẠY NGẦM (BACKGROUND WORKER)
// Tự động dọn dẹp ghế hết hạn mỗi 1 phút một lần
// =========================================================================
setInterval(async () => {
    try {
        // ✅ ĐÃ FIX LỖI: Chỉ xóa những ghế mà ExpiredAt thật sự nhỏ hơn thời gian HIỆN TẠI
        const sql = `DELETE FROM seatholds WHERE ExpiredAt <= NOW()`;
        
        const [result] = await db.promise().query(sql);
        
        if (result.affectedRows > 0) {
            console.log(`🧹 [CronJob] Đã tự động nhả ${result.affectedRows} ghế bị giữ quá hạn (hết 10 phút)!`);
        }
    } catch (error) {
        console.error("❌ Lỗi dọn ghế tự động chạy ngầm:", error.message);
    }
}, 60000); // Quét mỗi 1 phút

const adminRoutes = require('./admin.route'); 
app.use('/api/admin', adminRoutes);

// 🚀 TUYỆT CHIÊU: Biến thư mục assets của Flutter thành thư mục tĩnh của Backend
app.use('/assets', express.static(path.join(__dirname, '../doan_mobile/assets')));
// Cấp quyền truy cập công khai cho thư mục uploads
app.use('/public', express.static(path.join(__dirname, 'public')));


// =========================================================================
// 🚀 HỆ THỐNG SOCKET.IO REAL-TIME (XỬ LÝ GIỮ/NHẢ GHẾ THỜI GIAN THỰC)
// =========================================================================
io.on('connection', (socket) => {
    console.log('✅ Có một thiết bị vừa kết nối Socket:', socket.id);

    // 1. Tham gia phòng theo suất chiếu (Để khách xem phim A không bị nháy ghế phim B)
    socket.on('join_showtime', (showtimeId) => {
        socket.join(`showtime_${showtimeId}`);
        console.log(`📱 User ${socket.id} đã vào phòng xem sơ đồ phim suất: ${showtimeId}`);
    });

    // 2. Rời phòng chiếu
    socket.on('leave_showtime', (showtimeId) => {
        socket.leave(`showtime_${showtimeId}`);
    });

    // 3. Sự kiện Khách vừa BẤM CHỌN GHẾ (Hold)
    socket.on('hold_seat', async (data) => {
        const { userId, showtimeId, seatId, seatNumber } = data;
        try {
            // Lưu vào MySQL
            const sql = `
                INSERT IGNORE INTO seatholds (UserID, ShowtimeID, SeatID, ExpiredAt, Status) 
                VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE), 'holding')
            `;
            await db.promise().query(sql, [userId, showtimeId, seatId]);

            // Phát tín hiệu cho TẤT CẢ các máy khác đang xem cùng suất chiếu này chuyển ghế sang màu cam
            io.to(`showtime_${showtimeId}`).emit('seat_status_changed', {
                seatNumber: seatNumber,
                status: 'holding'
            });
        } catch (error) {
            console.error("Lỗi Socket hold ghế:", error);
        }
    });

    // 4. Sự kiện Khách BẤM BỎ CHỌN GHẾ (Release)
    socket.on('release_seat', async (data) => {
        const { userId, showtimeId, seatId, seatNumber } = data;
        try {
            // Xóa khỏi MySQL
            const sql = `DELETE FROM seatholds WHERE UserID = ? AND ShowtimeID = ? AND SeatID = ?`;
            await db.promise().query(sql, [userId, showtimeId, seatId]);

            // Phát tín hiệu cho các máy khác nhả màu ghế về bình thường
            io.to(`showtime_${showtimeId}`).emit('seat_status_changed', {
                seatNumber: seatNumber,
                status: 'available'
            });
        } catch (error) {
            console.error("Lỗi Socket release ghế:", error);
        }
    });

    socket.on('disconnect', () => {
        console.log('❌ Thiết bị đã ngắt kết nối Socket:', socket.id);
    });
});

// Thêm route GET /api/seattypes
app.get('/api/seattypes', (req, res) => {
    // Chú ý: Đổi chữ 'seattypes' thành đúng tên bảng loại ghế trong MySQL của ông
    const sql = 'SELECT * FROM seattypes'; 
    
    db.query(sql, (err, results) => {
        if (err) {
            console.error("Lỗi khi lấy danh sách loại ghế:", err);
            return res.status(500).json({ message: "Lỗi server" });
        }
        // Trả thẳng mảng dữ liệu về cho App và Web
        res.status(200).json(results); 
    });
});
// Thêm API lấy bảng giá vé (Ticket Prices Matrix)
app.get('/api/ticketprices', (req, res) => {
    const sql = `
        SELECT t.*, c.name as CinemaName 
        FROM ticketprices t 
        LEFT JOIN cinemas c ON t.CinemaID = c.id
        WHERE t.IsActive = 1
    `;
    db.query(sql, (err, results) => {
        if(err) return res.status(500).send(err);
        res.json(results);
    });
});

// Hẹn giờ chạy vào 23:55 mỗi đêm
cron.schedule('55 23 * * *', async () => {
    try {
        // Lấy doanh thu ngày hôm nay
        const [rows] = await db.promise().query(`
            SELECT SUM(TotalAmount) as total 
            FROM bookings 
            WHERE Status = 'Paid' AND DATE(CreatedAt) = CURDATE()
        `);
        const dailyRevenue = rows[0].total || 0;
        const formatMoney = new Intl.NumberFormat('vi-VN').format(dailyRevenue) + ' đ';

        // Tự động đẩy thông báo vào DB cho Admin đọc
        const notifSql = `INSERT INTO notifications (Title, Type, Content, ActionURL, IsRead, CreatedAt) VALUES (?, ?, ?, ?, 0, NOW())`;
        await db.promise().query(notifSql, [
            "📊 Báo cáo cuối ngày", 
            "REPORT", 
            `Tổng doanh thu hôm nay đạt: ${formatMoney}. Nhấn để xem chi tiết.`, 
            "/reports"
        ]);
        console.log("Đã tạo thông báo báo cáo ngày tự động!");
    } catch (error) {
        console.log("Lỗi cronjob:", error);
    }
});

// =======================================================
// 1. API QUÊN MẬT KHẨU -> GỬI OTP VÀO EMAIL
// =======================================================
app.post('/api/forgot-password', async (req, res) => {
    const { email } = req.body;

    try {
        // 1. Kiểm tra Email có tồn tại trong CSDL không
        const [users] = await db.promise().query("SELECT UserID FROM users WHERE Email = ?", [email]);
        if (users.length === 0) {
            return res.status(404).json({ error: "Email không tồn tại trong hệ thống!" });
        }

        // 2. Tạo mã OTP ngẫu nhiên 6 số
        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        // 3. 🚀 LƯU OTP VÀO RAM (Không đụng tới MySQL)
        // Key là email, Value là mã OTP. Nó sẽ tự động biến mất sau 5 phút.
        otpCache.set(email, otp);

        console.log(`[CACHE] Đã lưu OTP ${otp} cho user ${email} vào RAM.`);

        // 4. Lấy cấu hình SMTP từ bảng systemconfigs
        const [configRows] = await db.promise().query(
            "SELECT ConfigKey, ConfigValue FROM systemconfigs WHERE ConfigKey IN ('smtpHost', 'smtpPort', 'smtpUser', 'smtpPass')"
        );
        
        let smtp = {};
        configRows.forEach(row => smtp[row.ConfigKey] = row.ConfigValue);

        if (!smtp.smtpHost || !smtp.smtpUser || !smtp.smtpPass) {
            return res.status(500).json({ error: "Hệ thống chưa cấu hình Mail Server trong Admin!" });
        }

        // 5. Cấu hình gửi mail
        const transporter = nodemailer.createTransport({
            host: smtp.smtpHost,
            port: Number(smtp.smtpPort),
            secure: Number(smtp.smtpPort) === 465,
            auth: {
                user: smtp.smtpUser,
                pass: smtp.smtpPass
            }
        });

        // 6. Bắn Mail
        await transporter.sendMail({
            from: `"Cinema Tickets" <${smtp.smtpUser}>`,
            to: email,
            subject: "Mã xác nhận khôi phục mật khẩu",
            html: `
                <div style="font-family: Arial, sans-serif; padding: 20px; text-align: center;">
                    <h2>Khôi phục mật khẩu</h2>
                    <p>Mã xác nhận (OTP) của bạn là:</p>
                    <h1 style="color: #1565C0; font-size: 40px; letter-spacing: 5px; background: #f4f4f4; padding: 10px; border-radius: 8px; display: inline-block;">${otp}</h1>
                    <p style="color: red;">* Mã này chỉ có hiệu lực trong vòng 5 phút.</p>
                    <p>Vui lòng không chia sẻ mã này cho bất kỳ ai!</p>
                </div>
            `
        });

        res.json({ message: "Mã OTP đã được gửi đến email của bạn!" });

    } catch (error) {
        console.error("Lỗi gửi mail OTP:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi gửi email!" });
    }
});


// ==========================================
// API: XÁC NHẬN OTP & ĐỔI MẬT KHẨU MỚI
// ==========================================
app.post('/api/reset-password', async (req, res) => {
    const { email, otp, newPassword } = req.body;

    // 1. Kiểm tra dữ liệu đầu vào
    if (!email || !otp || !newPassword) {
        return res.status(400).json({ error: "Vui lòng nhập đầy đủ Email, Mã OTP và Mật khẩu mới!" });
    }

    try {
        // 2. 🚀 ĐỌC OTP TỪ RAM RA
        // (Lưu ý: Khúc gửi OTP Quên mật khẩu mình dùng key là email, nên gọi ra cũng bằng email)
        const cachedOtp = otpCache.get(email);

        if (!cachedOtp) {
            return res.status(400).json({ error: "Mã OTP đã hết hạn hoặc không tồn tại. Vui lòng yêu cầu gửi lại!" });
        }

        if (cachedOtp !== otp.toString()) {
            return res.status(400).json({ error: "Mã OTP không chính xác!" });
        }

        // 3. OTP Đúng -> Lập tức xóa khỏi RAM để không bị dùng lại
        otpCache.del(email);

        // 4. Mã hóa mật khẩu mới (Băm 12 vòng - Đồng bộ với API Đăng ký)
        const hashedPassword = await bcrypt.hash(newPassword, 12);

        // 5. Cập nhật mật khẩu xuống Database
        const sql = 'UPDATE users SET PasswordHash = ? WHERE Email = ?';
        await db.promise().query(sql, [hashedPassword, email]);

        res.status(200).json({ success: true, message: "Đổi mật khẩu thành công! Vui lòng đăng nhập lại." });

    } catch (error) {
        console.error("❌ Lỗi khi đổi mật khẩu:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi đổi mật khẩu. Vui lòng thử lại sau!" });
    }
});

// ==========================================
// API: LẤY THÔNG TIN LIÊN HỆ TỪ ADMIN
// ==========================================
app.get('/api/contact-info', async (req, res) => {
    try {
        // Giả sử ông lưu bằng các Key này trong bảng systemconfigs
        // (Nếu ông dùng bảng khác hoặc key khác thì sửa lại tên cột nhé)
        const sql = "SELECT ConfigKey, ConfigValue FROM systemconfigs WHERE ConfigKey IN ('cinemaName', 'hotline', 'supportEmail', 'address')";
        
        const [rows] = await db.promise().query(sql);
        
        // Chuyển mảng kết quả thành Object cho Flutter dễ đọc
        let contactInfo = {};
        rows.forEach(row => {
            contactInfo[row.ConfigKey] = row.ConfigValue;
        });

        // Nếu trong DB chưa có cấu hình, trả về chuỗi rỗng để App tự xử lý
        res.status(200).json({
            cinemaName: contactInfo['cinemaName'] || "CinemaTickets",
            hotline: contactInfo['hotline'] || "",
            supportEmail: contactInfo['supportEmail'] || "hotro@cinematickets.vn",
            address: contactInfo['address'] || ""
        });

    } catch (error) {
        console.error("❌ Lỗi khi lấy cấu hình liên hệ:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi lấy thông tin liên hệ!" });
    }
});

// =======================================================
// API 1: LẤY DANH SÁCH THÔNG BÁO CỦA KHÁCH HÀNG (Dành cho App)
// =======================================================
app.get('/api/users/:userId/notifications', async (req, res) => {
    const userId = req.params.userId;
    try {
        // Chỉ lấy đúng thông báo của User đó (có UserID khớp)
        const sql = 'SELECT * FROM notifications WHERE UserID = ? ORDER BY CreatedAt DESC LIMIT 30';
        const [notifications] = await db.promise().query(sql, [userId]);
        res.json(notifications);
    } catch (error) {
        console.error("Lỗi lấy thông báo App:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =======================================================
// API 2: KHÁCH HÀNG BẤM VÀO THÔNG BÁO THÌ ĐÁNH DẤU LÀ "ĐÃ ĐỌC"
// =======================================================
app.put('/api/users/notifications/:notifId/read', async (req, res) => {
    const notifId = req.params.notifId;
    try {
        const sql = 'UPDATE notifications SET IsRead = 1 WHERE NotificationID = ?';
        await db.promise().query(sql, [notifId]);
        res.json({ success: true, message: "Đã đọc!" });
    } catch (error) {
        console.error("Lỗi đọc thông báo App:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// ==========================================
// 5. KHỞI ĐỘNG SERVER
// ==========================================
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`🚀 Server backend (kèm Socket.IO) đang chạy tại port: ${PORT}`);
});