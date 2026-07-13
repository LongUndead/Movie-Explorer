// File: admin.route.js
const express = require('express');
const router = express.Router();
const axios = require('axios'); // Thêm cái này vì cào phim cần dùng axios
const db = require('./db'); // Import DB dùng chung
const bcrypt = require('bcryptjs'); // Bắt buộc phải có để so sánh mật khẩu
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// =====================================================================
// CẤU HÌNH MULTER THÔNG MINH (Phân loại ảnh tự động)
// =====================================================================
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        // 1. Mặc định là lưu ảnh Phim vào thư mục uploads
        let dir = path.join(__dirname, 'public/uploads'); 
        
        // 2. Nếu tên biến gửi lên là 'avatar' (của User) hoặc 'avatar_file' (của Diễn viên) -> Bẻ lái sang thư mục avatars
        if (file.fieldname === 'avatar' || file.fieldname === 'avatar_file') {
            dir = path.join(__dirname, 'public/avatars');
        }
        // 🚀 3. THÊM ĐIỀU KIỆN NÀY: Nếu biến gửi lên là 'food_file' (của Bắp nước) -> Bẻ lái sang thư mục foods
        else if (file.fieldname === 'food_file') {
            dir = path.join(__dirname, 'public/foods');
        }
        
        // Tự tạo thư mục tương ứng nếu chưa có trong project
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true }); 
        cb(null, dir);
    },
    filename: function (req, file, cb) {
        // 🚀 CẬP NHẬT LOGIC ĐẶT TÊN: Tự động gắn tiền tố tương ứng cho từng loại ảnh
        let prefix = 'movie-';
        
        if (file.fieldname === 'avatar' || file.fieldname === 'avatar_file') {
            prefix = 'avatar-';
        } else if (file.fieldname === 'food_file') {
            prefix = 'food-';
        }
        
        cb(null, prefix + Date.now() + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });
// =====================================================================
// 1. API THỐNG KÊ DASHBOARD (SỬA LỖI LỌC NGÀY + DỮ LIỆU CẢNH BÁO THẬT)
// =====================================================================
router.get('/dashboard/summary', async (req, res) => {
    const cinemaId = req.query.cinemaId;
    const targetDate = req.query.date; // Bắt chính xác tham số date từ Frontend gửi lên

    let filterStr = "";
    let params = [];

    // Lọc theo Rạp
    if (cinemaId && cinemaId !== 'ALL') {
        filterStr += " AND r.CinemaID = ? ";
        params.push(cinemaId);
    }

    // Lọc theo Ngày Cụ Thể (Dựa vào ngày tạo hóa đơn CreatedAt)
    if (targetDate) {
        filterStr += " AND DATE(b.CreatedAt) = ? ";
        params.push(targetDate);
    }

    try {
        // 1. TỔNG DOANH THU THỰC TẾ
        const statsSql = `
            SELECT SUM(b.TotalAmount) as totalRevenue
            FROM bookings b
            JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            JOIN rooms r ON st.RoomID = r.RoomID
            WHERE b.Status = 'Paid' ${filterStr}
        `;
        
        // 2. DOANH THU VÉ & TỔNG VÉ
        const ticketSql = `
            SELECT COUNT(bs.SeatID) as totalTickets, SUM(bs.Price) as ticketRevenue
            FROM bookingseats bs
            JOIN bookings b ON bs.BookingID = b.BookingID
            JOIN showtimes st ON bs.ShowtimeID = st.ShowtimeID
            JOIN rooms r ON st.RoomID = r.RoomID
            WHERE b.Status = 'Paid' ${filterStr}
        `;

        // 3. DOANH THU BẮP NƯỚC
        const foodSql = `
            SELECT SUM(f.Price * bf.Quantity) as foodRevenue
            FROM bookingfoods bf
            JOIN foods f ON bf.FoodID = f.FoodID
            JOIN bookings b ON bf.BookingID = b.BookingID
            JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            JOIN rooms r ON st.RoomID = r.RoomID
            WHERE b.Status = 'Paid' ${filterStr}
        `;

        // 4. TOP 5 PHIM NỔI BẬT
        const topMoviesSql = `
            SELECT m.title, m.poster_path, SUM(bs.Price) as revenue, COUNT(bs.SeatID) as tickets
            FROM bookingseats bs
            JOIN bookings b ON bs.BookingID = b.BookingID
            JOIN showtimes st ON bs.ShowtimeID = st.ShowtimeID
            JOIN movies m ON st.MovieID = m.id
            JOIN rooms r ON st.RoomID = r.RoomID
            WHERE b.Status = 'Paid' ${filterStr}
            GROUP BY m.id, m.title, m.poster_path
            ORDER BY revenue DESC
            LIMIT 5
        `;

        // 5. GIAO DỊCH GẦN ĐÂY
        const recentBookingsSql = `
            SELECT 
                b.BookingID as id, m.title as movie, 
                DATE_FORMAT(st.StartTime, '%H:%i') as time, 
                DATE_FORMAT(st.StartTime, '%d/%m/%Y') as date,
                b.TotalAmount as price, b.Status as status,
                (SELECT GROUP_CONCAT(s2.SeatNumber SEPARATOR ', ') 
                 FROM bookingseats bs2 JOIN seats s2 ON bs2.SeatID = s2.SeatID 
                 WHERE bs2.BookingID = b.BookingID) AS seats
            FROM bookings b
            JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            JOIN movies m ON st.MovieID = m.id
            JOIN rooms r ON st.RoomID = r.RoomID
            WHERE 1=1 ${filterStr}
            ORDER BY b.CreatedAt DESC
            LIMIT 10
        `;

        // 6. TOP 5 BẮP NƯỚC BÁN CHẠY NHẤT
        const topFoodsSql = `
            SELECT 
                f.Name as name, 
                f.ImageURL as image, 
                f.brand_id as brandId, 
                SUM(bf.Quantity) as quantity, 
                SUM(f.Price * bf.Quantity) as revenue
            FROM bookingfoods bf
            JOIN foods f ON bf.FoodID = f.FoodID
            JOIN bookings b ON bf.BookingID = b.BookingID
            JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            JOIN rooms r ON st.RoomID = r.RoomID
            WHERE b.Status = 'Paid' ${filterStr}
            GROUP BY f.FoodID, f.Name, f.ImageURL, f.brand_id
            ORDER BY quantity DESC
            LIMIT 5
        `;

        // =================================================================
        // 7. DỮ LIỆU THẬT: CÁC SUẤT CHIẾU BỊ Ế GHẾ (DƯỚI 30% CÔNG SUẤT)
        // =================================================================
        let warningFilterStr = "";
        let warningParams = [];

        if (cinemaId && cinemaId !== 'ALL') {
            warningFilterStr += " AND r.CinemaID = ? ";
            warningParams.push(cinemaId);
        }
        if (targetDate) {
            warningFilterStr += " AND DATE(st.StartTime) = ? "; // Lọc theo ngày chiếu
            warningParams.push(targetDate);
        }

        const warningSql = `
            SELECT 
                st.ShowtimeID as id,
                m.title as movieName,
                r.Name as roomName,
                DATE_FORMAT(st.StartTime, '%H:%i') as startTime,
                
                /* Đếm tổng số ghế của phòng đó */
                (SELECT COUNT(*) FROM seats s WHERE s.RoomID = r.RoomID) as totalSeats,
                
                /* Đếm số vé đã bán được của suất chiếu đó */
                (SELECT COUNT(*) FROM bookingseats bs 
                 JOIN bookings b2 ON bs.BookingID = b2.BookingID 
                 WHERE bs.ShowtimeID = st.ShowtimeID AND b2.Status = 'Paid') as bookedSeats
                 
            FROM showtimes st
            JOIN movies m ON st.MovieID = m.id
            JOIN rooms r ON st.RoomID = r.RoomID
            WHERE 1=1 ${warningFilterStr}
            
            /* ĐIỀU KIỆN LỌC: Nếu số vé bán ra NHỎ HƠN 30% tổng số ghế thì mới lọt vào danh sách ế */
            HAVING bookedSeats < (totalSeats * 0.3) AND totalSeats > 0
            
            ORDER BY st.StartTime ASC
            LIMIT 5
        `;

        // Chạy tất cả các query song song
        const [statsRes] = await db.promise().query(statsSql, params);
        const [ticketRes] = await db.promise().query(ticketSql, params);
        const [foodRes] = await db.promise().query(foodSql, params);
        const [topMoviesRes] = await db.promise().query(topMoviesSql, params);
        const [recentRes] = await db.promise().query(recentBookingsSql, params);
        const [topFoodsRes] = await db.promise().query(topFoodsSql, params);
        const [warningRes] = await db.promise().query(warningSql, warningParams);

        // Trả data về cho React
        res.json({
            totalRevenue: statsRes[0].totalRevenue || 0,
            ticketRevenue: ticketRes[0].ticketRevenue || 0,
            foodRevenue: foodRes[0].foodRevenue || 0,
            totalTickets: ticketRes[0].totalTickets || 0,
            topMovies: topMoviesRes || [],
            recentBookings: recentRes || [],
            topFoods: topFoodsRes || [],
            warningShowtimes: warningRes || [] // Trả list các suất chiếu ế về
        });

    } catch (error) {
        console.error("Lỗi Dashboard API:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// =====================================================================
// API ĐĂNG NHẬP DÀNH RIÊNG CHO QUẢN TRỊ VIÊN
// =====================================================================
router.post('/login', async (req, res) => {
    const { email, password } = req.body;
    try {
        // 1. Tìm user và chức vụ (Join bảng users, userroles, roles)
        const sql = `
            SELECT u.UserID, u.Username, u.Email,u.Phone,u.Avatar, u.PasswordHash, r.RoleName 
            FROM users u
            LEFT JOIN userroles ur ON u.UserID = ur.UserID
            LEFT JOIN roles r ON ur.RoleID = r.RoleID
            WHERE u.Email = ?
        `;
        const [users] = await db.promise().query(sql, [email]);
        
        if (users.length === 0) {
            return res.status(401).json({ error: "Email không tồn tại trong hệ thống!" });
        }

        const user = users[0];

        // 2. SO SÁNH MẬT KHẨU TRƯỚC (Authentication)
        const isMatch = await bcrypt.compare(password, user.PasswordHash);
        if (!isMatch) {
            return res.status(401).json({ error: "Mật khẩu không chính xác!" });
        }

        // 3. SO SÁNH QUYỀN HẠN SAU (Authorization)
        // Dùng .toLowerCase() để ép chuỗi 'Admin' thành 'admin', đề phòng gõ sai hoa/thường trong DB
        if (!user.RoleName || user.RoleName.toLowerCase() !== 'admin') {
            return res.status(403).json({ error: "Truy cập bị từ chối! Bạn không có quyền Quản trị viên." });
        }

        // 4. Thành công: Xóa mật khẩu mảng băm đi trước khi gửi về React để bảo mật
        delete user.PasswordHash;
        res.json({ success: true, message: "Đăng nhập Admin thành công", user: user });

    } catch (error) {
        console.error("Lỗi đăng nhập Admin:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// =====================================================================
// 2. CÁC CÔNG CỤ QUẢN TRỊ VIÊN (TOOL ADMIN) - Tách từ index.js sang
// =====================================================================

router.get('/auto-setup', async (req, res) => {
    try {
        // =========================================================================
        // 1. DỌN DẸP SẠCH RÁC CŨ ĐỂ TRÁNH LỖI RÀNG BUỘC KHÓA NGOẠI (FOREIGN KEY)
        // =========================================================================
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 0");
        // Dọn sạch hóa đơn, giữ chỗ, bắp nước cũ trước
        await db.promise().query("TRUNCATE TABLE bookingfoods");
        await db.promise().query("TRUNCATE TABLE bookingseats");
        await db.promise().query("TRUNCATE TABLE seatholds");
        await db.promise().query("TRUNCATE TABLE payments");
        await db.promise().query("TRUNCATE TABLE bookings");
        // Dọn rạp, suất chiếu, ghế
        await db.promise().query("TRUNCATE TABLE showtimes");
        await db.promise().query("TRUNCATE TABLE seats"); 
        await db.promise().query("DELETE FROM rooms WHERE Name LIKE '%Rạp 2%' OR Name LIKE '%Rạp 3%' OR Name LIKE '%Rạp 4%' OR Name LIKE '%Rạp 5%'");
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 1");

        // Helper tính số lượng ghế
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

        // Helper tính giá tiền
        const getExactPrice = (cinemaName, format) => {
            const name = cinemaName.toLowerCase();
            let base = 85000;
            if (name.includes('cgv')) base = 100000;
            else if (name.includes('lotte')) base = 95000;
            else if (name.includes('galaxy') || name.includes('bhd')) base = 90000;
            else if (name.includes('mega') || name.includes('dcine')) base = 65000;
            else if (name.includes('cinestar')) base = 55000;
            else if (name.includes('beta')) base = 50000;

            if (format.includes('3D')) base += 30000;
            if (format.includes('IMAX')) base += 50000;
            if (format.includes('4DX')) base += 70000;
            if (format.includes('Premium')) base += 40000;
            return base;
        };

        // =========================================================================
        // 2. KHỞI TẠO PHÒNG CHIẾU (ROOMS)
        // =========================================================================
        const [existingRooms] = await db.promise().query("SELECT RoomID, Name FROM rooms");
        for (const room of existingRooms) {
            const exactCapacity = getExactCapacity(room.Name);
            await db.promise().query("UPDATE rooms SET TotalSeats = ? WHERE RoomID = ?", [exactCapacity, room.RoomID]);
        }

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

        // =========================================================================
        // 3. KHỞI TẠO SUẤT CHIẾU (SHOWTIMES) VÀ TÍNH ENDTIME
        // =========================================================================
        const [movies] = await db.promise().query("SELECT id, COALESCE(duration, 120) as duration FROM movies");
        const [allRoomsFinal] = await db.promise().query("SELECT RoomID, Name, COALESCE(BufferMinutes, 10) as buffer FROM rooms");

        if (movies.length === 0) return res.status(400).json({ error: "Vui lòng chạy sync-movies trước!" });

        const showtimeValues = [];
        const daysToSchedule = 7; 
        const now = new Date();
        let movieIndex = 0; 
        const formatOptions = ['2D Phụ đề',  '2D Phụ đề', '2D Lồng Tiếng', '2D Phụ đề', 'IMAX', '4DX', '3D Phụ đề', '2D Premium'];

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
                    
                    // Tính StartTime
                    const formattedStartTime = `${currentStartTime.getFullYear()}-${pad(currentStartTime.getMonth() + 1)}-${pad(currentStartTime.getDate())} ${pad(currentStartTime.getHours())}:${pad(currentStartTime.getMinutes())}:00`;

                    // Tính EndTime
                    const endDateTime = new Date(currentStartTime.getTime() + currentMovie.duration * 60000);
                    const formattedEndTime = `${endDateTime.getFullYear()}-${pad(endDateTime.getMonth() + 1)}-${pad(endDateTime.getDate())} ${pad(endDateTime.getHours())}:${pad(endDateTime.getMinutes())}:00`;

                    const randomFormat = formatOptions[Math.floor(Math.random() * formatOptions.length)];
                    const finalPrice = getExactPrice(room.Name, randomFormat);

                    showtimeValues.push([currentMovie.id, room.RoomID, formattedStartTime, formattedEndTime, finalPrice, isCinetour, randomFormat]);

                    const totalMinutesToAdd = currentMovie.duration + room.buffer + 10; 
                    currentStartTime.setMinutes(currentStartTime.getMinutes() + totalMinutesToAdd);
                }
            }
        }

        if (showtimeValues.length > 0) {
            await db.promise().query("INSERT INTO showtimes (MovieID, RoomID, StartTime, EndTime, Price, cinetour, movie_format) VALUES ?", [showtimeValues]);
        }

        // =========================================================================
        // 4. KHỞI TẠO GHẾ THEO TỈ LỆ CHUẨN CỦA FLUTTER (SEATS)
        // =========================================================================
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
                    
                    // Quy tắc đổi màu ghế y chang App Flutter
                    let seatType = 1; // Ghế thường
                    if (count > capacity * 0.4) seatType = 2; // Ghế VIP
                    if (count > capacity * 0.85) seatType = 3; // Ghế Sweetbox

                    seatValues.push([room.RoomID, `${letters[r]}${c}`, seatType]);
                    count++;
                }
                if (count >= capacity) break;
            }

            if (seatValues.length > 0) {
                await db.promise().query("INSERT INTO seats (RoomID, SeatNumber, SeatTypeID) VALUES ?", [seatValues]);
                totalSeatsInserted += seatValues.length;
            }
        }

        res.json({ success: true, message: `🔥 ĐÃ SETUP HOÀN HẢO: Đúc ${totalSeatsInserted} ghế vật lý. Tạo ${showtimeValues.length} suất chiếu!` });
    } catch (error) {
        console.error("Lỗi auto-setup:", error);
        res.status(500).json({ error: error.message });
    }
});

// 2.2 DỌN DẸP RÁC THÔNG MINH
router.get('/clean-up', async (req, res) => {
    try {
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 0");

        const [holdResult] = await db.promise().query(`DELETE FROM seatholds WHERE ExpiredAt < NOW()`);
        await db.promise().query(`
            DELETE bs FROM bookingseats bs 
            JOIN bookings b ON bs.BookingID = b.BookingID 
            WHERE b.Status = 'Pending' AND b.CreatedAt < DATE_SUB(NOW(), INTERVAL 30 MINUTE)
        `);
        const [bookingResult] = await db.promise().query(`
            DELETE FROM bookings 
            WHERE Status = 'Pending' AND CreatedAt < DATE_SUB(NOW(), INTERVAL 30 MINUTE)
        `);
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
            message: `🧹 ĐÃ DỌN DẸP TOÀN DIỆN HỆ THỐNG! Xóa ${holdResult.affectedRows} ghế kẹt, ${bookingResult.affectedRows} hóa đơn rác.` 
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ==========================================================
// 2.3 CÀO PHIM TỪ TMDB (ĐÃ CHUẨN HÓA CHỈ LẤY PHIM CHIẾU RẠP)
// ==========================================================
router.get('/sync-movies', async (req, res) => {
    const TMDB_API_KEY = '1f555345923a2d2034eae91200dfb80e'; 
    const pagesToFetch = 5; // Số trang cho mỗi loại (2 trang = 40 phim/loại)
    
    // Tự động tính toán các mốc thời gian thực tế
    const todayObj = new Date();
    const today = todayObj.toISOString().slice(0, 10); // Hôm nay
    
    const pastObj = new Date();
    pastObj.setDate(todayObj.getDate() - 60); // Phim Đang chiếu: Trong vòng 2 tháng đổ lại
    const pastDate = pastObj.toISOString().slice(0, 10);
    
    const futureObj = new Date();
    futureObj.setDate(todayObj.getDate() + 90); // Phim Sắp chiếu: Giới hạn trong 3 tháng tới
    const futureDate = futureObj.toISOString().slice(0, 10);

    let totalSynced = 0;

    try {
        // 1. Lấy danh sách thể loại từ TMDB để map ID sang Tên
        const genreRes = await axios.get(`https://api.themoviedb.org/3/genre/movie/list?api_key=${TMDB_API_KEY}&language=vi-VN`);
        const genreMap = {};
        genreRes.data.genres.forEach(g => genreMap[g.id] = g.name);

        // 2. Tự động sinh ra danh sách link quét đa dạng (ĐÃ THÊM LỌC RẠP VÀ LỌC RÁC)
        const fetchUrls = [];
        
        // 🍿 NHÓM 1: PHIM ĐANG CHIẾU (NOW PLAYING)
        for (let page = 1; page <= pagesToFetch; page++) {
            fetchUrls.push(
                `https://api.themoviedb.org/3/discover/movie?api_key=${TMDB_API_KEY}&language=vi-VN&primary_release_date.gte=${pastDate}&primary_release_date.lte=${today}&with_release_type=2|3&vote_count.gte=5&sort_by=popularity.desc&page=${page}`
            );
        }

        // 🚀 NHÓM 2: PHIM SẮP CHIẾU (UPCOMING)
        for (let page = 1; page <= pagesToFetch; page++) {
            fetchUrls.push(
                `https://api.themoviedb.org/3/discover/movie?api_key=${TMDB_API_KEY}&language=vi-VN&primary_release_date.gt=${today}&primary_release_date.lte=${futureDate}&with_release_type=2|3&sort_by=popularity.desc&page=${page}`
            );
        }

        // 🇻🇳 NHÓM 3: PHIM VIỆT NAM CHIẾU RẠP (Mở rộng từ 2024 để hốt phim Việt)
        fetchUrls.push(
            `https://api.themoviedb.org/3/discover/movie?api_key=${TMDB_API_KEY}&language=vi-VN&with_original_language=vi&primary_release_date.gte=2024-01-01&with_release_type=2|3&sort_by=popularity.desc&page=1`
        );

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

        res.json({ success: true, message: `🚀 Đã "hốt" trọn vẹn ${totalSynced} phim (Chiếu rạp Xịn, không rác)!` });
    } catch (error) {
        console.error("❌ Lỗi Tổng:", error);
        res.status(500).json({ error: error.message });
    }
});

// 2.4 QUÉT SẠCH KHO PHIM
router.get('/clear-all-movies', async (req, res) => {
    try {
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 0");
        await db.promise().query("TRUNCATE TABLE movies");
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 1");
        
        res.json({ success: true, message: "🗑️ Đã quét sạch bảng phim!" });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 2.5 DỌN BÀI NHƯỢNG VÉ CỘNG ĐỒNG QUÁ HẠN
router.get('/cleanup-transfers', async (req, res) => {
    try {
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
        res.json({ success: true, message: `Đã đóng ${result.affectedRows} bài nhượng vé quá hạn.` });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =====================================================================
// 3. QUẢN LÝ PHIM (MOVIES)
// =====================================================================
router.get('/movies', async (req, res) => {
    try {
        // Dùng SELECT * để đảm bảo lấy đủ TrailerURL, cast, overview, backdrop_path...
        const [movies] = await db.promise().query('SELECT * FROM movies ORDER BY release_date DESC');
        res.json(movies);
    } catch (error) {
        console.error("❌ Lỗi lấy danh sách phim Admin:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});
// =====================================================================
// API: THÊM PHIM MỚI (HỖ TRỢ TẢI LÊN NHIỀU ẢNH BACKDROP CÙNG LÚC)
// =====================================================================
router.post('/movies', upload.fields([{ name: 'poster_file', maxCount: 1 }, { name: 'backdrop_file', maxCount: 10 }]), async (req, res) => {
    const { title, genres, duration, release_date, language, age_rating, vote_average, overview, poster_path, backdrop_path, TrailerURL, cast } = req.body;
    
    const finalPoster = req.files && req.files['poster_file'] ? `/uploads/${req.files['poster_file'][0].filename}` : poster_path;
    
    // 🚀 THUẬT TOÁN GOM ẢNH: Trộn cả Link nhập tay và File tải lên vào chung 1 mảng JSON
    let backdropArray = [];
    if (backdrop_path && backdrop_path.trim() !== '') {
        if (backdrop_path.startsWith('[')) {
            try { backdropArray = JSON.parse(backdrop_path); } catch(e) {}
        } else {
            backdropArray = backdrop_path.split(',').map(s => s.trim()).filter(s => s !== '');
        }
    }
    if (req.files && req.files['backdrop_file']) {
        req.files['backdrop_file'].forEach(file => {
            backdropArray.push(`/uploads/${file.filename}`);
        });
    }
    const finalBackdrop = backdropArray.length > 0 ? JSON.stringify(backdropArray) : '';

    try {
        const sql = `INSERT INTO movies (title, genres, duration, release_date, language, age_rating, vote_average, overview, poster_path, backdrop_path, TrailerURL, cast, IsDeleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`;
        await db.promise().query(sql, [
            title, genres || '', duration, release_date || null, language, age_rating, vote_average, overview, finalPoster, finalBackdrop, TrailerURL || '', cast || ''
        ]);
        res.json({ success: true, message: "Thêm phim thành công!" });
    } catch (error) {
        console.error("Lỗi thêm phim:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =====================================================================
// API: SỬA THÔNG TIN PHIM (HỖ TRỢ TẢI LÊN NHIỀU ẢNH BACKDROP CÙNG LÚC)
// =====================================================================
router.put('/movies/:id', upload.fields([{ name: 'poster_file', maxCount: 1 }, { name: 'backdrop_file', maxCount: 10 }]), async (req, res) => {
    const { title, genres, duration, release_date, language, age_rating, vote_average, overview, poster_path, backdrop_path, TrailerURL, cast } = req.body;
    
    const finalPoster = req.files && req.files['poster_file'] ? `/uploads/${req.files['poster_file'][0].filename}` : poster_path;
    
    // 🚀 THUẬT TOÁN GOM ẢNH (Tương tự như Thêm)
    let backdropArray = [];
    if (backdrop_path && backdrop_path.trim() !== '') {
        if (backdrop_path.startsWith('[')) {
            try { backdropArray = JSON.parse(backdrop_path); } catch(e) {}
        } else {
            backdropArray = backdrop_path.split(',').map(s => s.trim()).filter(s => s !== '');
        }
    }
    if (req.files && req.files['backdrop_file']) {
        req.files['backdrop_file'].forEach(file => {
            backdropArray.push(`/uploads/${file.filename}`);
        });
    }
    const finalBackdrop = backdropArray.length > 0 ? JSON.stringify(backdropArray) : '';

    try {
        const sql = `UPDATE movies SET title=?, genres=?, duration=?, release_date=?, language=?, age_rating=?, vote_average=?, overview=?, poster_path=?, backdrop_path=?, TrailerURL=?, cast=? WHERE id=?`;
        await db.promise().query(sql, [
            title, genres || '', duration, release_date || null, language, age_rating, vote_average, overview, finalPoster, finalBackdrop, TrailerURL || '', cast || '', req.params.id
        ]);
        res.json({ success: true, message: "Cập nhật phim thành công!" });
    } catch (error) {
        console.error("Lỗi sửa phim:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// Ẩn/Hiện phim (Dựa vào cột IsDeleted)
router.put('/movies/:id/toggle-status', async (req, res) => {
    try {
        // ✅ SỬA: Lấy cột IsDeleted
        const [movie] = await db.promise().query("SELECT IsDeleted FROM movies WHERE id = ?", [req.params.id]);
        if (movie.length === 0) return res.status(404).json({ error: "Không tìm thấy phim" });

        // Logic: Đang 0 (Hiện) thì đổi thành 1 (Ẩn). Đang 1 (Ẩn) thì đổi về 0 (Hiện)
        const newStatus = movie[0].IsDeleted === 0 ? 1 : 0;

        // ✅ SỬA: Cập nhật cột IsDeleted
        await db.promise().query("UPDATE movies SET IsDeleted = ? WHERE id = ?", [newStatus, req.params.id]);
        
        res.json({ success: true, message: newStatus === 0 ? "Đã HIỆN phim lại trên App" : "Đã ẨN phim khỏi hệ thống" });
    } catch (error) {
        console.error("Lỗi ẩn/hiện phim:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =====================================================================
// API QUẢN LÝ NGƯỜI DÙNG & DANH SÁCH ĐEN (BLACKLIST)
// =====================================================================

// 1. Lấy danh sách User (Tự động đếm số lần hoàn vé)
router.get('/users', async (req, res) => {
    try {
        const sql = `
            SELECT u.UserID, u.Username, u.Email, u.Phone, u.Avatar, u.CreatedAt, u.IsLocked, u.UnlockTime, r.RoleName,
            (SELECT COUNT(*) FROM bookings b WHERE b.UserID = u.UserID AND b.Status = 'Refunded') as RefundCount
            FROM users u
            LEFT JOIN userroles ur ON u.UserID = ur.UserID
            LEFT JOIN roles r ON ur.RoleID = r.RoleID
            ORDER BY u.CreatedAt DESC
        `;
        const [users] = await db.promise().query(sql);

        // Tự động mở khóa nếu đã qua thời hạn UnlockTime
        const now = new Date();
        for (let user of users) {
            if (user.IsLocked === 1 && user.UnlockTime && new Date(user.UnlockTime) <= now) {
                await db.promise().query('UPDATE users SET IsLocked = 0, UnlockTime = NULL WHERE UserID = ?', [user.UserID]);
                user.IsLocked = 0;
                user.UnlockTime = null;
            }
        }
        res.json(users);
    } catch (error) {
        console.error("Lỗi lấy danh sách User:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 2. API Áp dụng hình phạt Danh sách đen (Tự động theo Luật)
router.put('/users/:id/apply-blacklist', async (req, res) => {
    const userId = req.params.id;
    try {
        // Đếm số lần hoàn vé thực tế
        const [[stats]] = await db.promise().query(`SELECT COUNT(*) as count FROM bookings WHERE UserID = ? AND Status = 'Refunded'`, [userId]);
        const refundCount = stats.count || 0;

        if (refundCount === 0) return res.status(400).json({ error: "Người dùng uy tín, không có lịch sử hoàn vé!" });

        let isLocked = 0;
        let unlockTime = null;
        let message = "";

        // LUẬT XỬ PHẠT CỦA BẠN:
        if (refundCount <= 2) {
            message = `⚠️ Đã hoàn vé ${refundCount} lần: Gửi thông báo CẢNH CÁO tới người dùng!`;
        } else if (refundCount === 3) {
            isLocked = 1;
            unlockTime = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000); // Cộng 3 ngày
            message = `⛔ Hoàn vé 3 lần: Đã KHÓA TÀI KHOẢN 3 NGÀY!`;
        } else if (refundCount === 4) {
            isLocked = 1;
            unlockTime = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000); // Cộng 5 ngày
            message = `⛔ Hoàn vé 4 lần: Đã KHÓA TÀI KHOẢN 5 NGÀY!`;
        } else if (refundCount === 5) {
            isLocked = 1;
            unlockTime = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // Cộng 7 ngày
            message = `⛔ Hoàn vé 5 lần: Đã KHÓA TÀI KHOẢN 7 NGÀY!`;
        } else {
            isLocked = 1;
            unlockTime = null; // Khóa vĩnh viễn
            message = `💀 Hoàn vé ${refundCount} lần: Đã KHÓA VĨNH VIỄN!`;
        }

        if (refundCount >= 3) {
            await db.promise().query('UPDATE users SET IsLocked = ?, UnlockTime = ? WHERE UserID = ?', [isLocked, unlockTime, userId]);
        }
        res.json({ success: true, message });
    } catch (error) {
        res.status(500).json({ error: "Lỗi hệ thống phạt Blacklist!" });
    }
});

// 3. API Mở khóa thủ công (Ân xá)
router.put('/users/:id/unlock', async (req, res) => {
    await db.promise().query('UPDATE users SET IsLocked = 0, UnlockTime = NULL WHERE UserID = ?', [req.params.id]);
    res.json({ success: true, message: "Đã ân xá, mở khóa thành công!" });
});

// 4. API Xóa tài khoản
router.delete('/users/:id', async (req, res) => {
    try {
        await db.promise().query('DELETE FROM userroles WHERE UserID = ?', [req.params.id]);
        await db.promise().query('DELETE FROM users WHERE UserID = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: "Không thể xóa do vướng lịch sử giao dịch!" });
    }
});

// =====================================================================
// [BỔ SUNG] API PHÂN QUYỀN VÀ THÊM QUẢN TRỊ VIÊN MỚI
// =====================================================================

// 1. API Thay đổi quyền hạn (Chuyển giữa Admin <-> User)
router.put('/users/:id/change-role', async (req, res) => {
    const userId = req.params.id;
    const { roleId } = req.body; // 1: Admin, 2: User

    try {
        // Xóa quyền cũ trong bảng trung gian userroles
        await db.promise().query('DELETE FROM userroles WHERE UserID = ?', [userId]);
        // Chèn quyền mới vào
        await db.promise().query('INSERT INTO userroles (UserID, RoleID) VALUES (?, ?)', [userId, roleId]);

        res.json({ success: true, message: "Thay đổi quyền hạn thành công!" });
    } catch (error) {
        console.error("Lỗi phân quyền:", error);
        res.status(500).json({ error: "Không thể thay đổi quyền hạn người dùng!" });
    }
});

// 2. API Tạo tài khoản Admin mới từ giao diện Web
router.post('/users/admin', async (req, res) => {
    const { username, email, phone, password } = req.body;

    try {
        // Kiểm tra xem Email đã tồn tại hay chưa
        const [existing] = await db.promise().query('SELECT * FROM users WHERE Email = ?', [email]);
        if (existing.length > 0) {
            return res.status(400).json({ error: "Email này đã được đăng ký trong hệ thống!" });
        }

        // Mã hóa mật khẩu theo chuẩn mã băm bcrypt (độ phức tạp 12)
        const salt = await bcrypt.genSalt(12);
        const hashedPassword = await bcrypt.hash(password, salt);

        // 1. Chèn vào bảng users
        const [result] = await db.promise().query(
            'INSERT INTO users (Username, Email, Phone, PasswordHash, CreatedAt, IsLocked) VALUES (?, ?, ?, ?, NOW(), 0)',
            [username, email, phone, hashedPassword]
        );
        const newUserId = result.insertId;

        // 2. Cấp ngay quyền Admin (RoleID = 1) vào bảng userroles
        await db.promise().query('INSERT INTO userroles (UserID, RoleID) VALUES (?, 1)', [newUserId]);

        res.json({ success: true, message: "Tạo tài khoản quản trị viên mới thành open thành công!" });
    } catch (error) {
        console.error("Lỗi tạo Admin:", error);
        res.status(500).json({ error: "Lỗi máy chủ khi tạo tài khoản quản trị!" });
    }
});

// =====================================================================
// API THÔNG TIN CÁ NHÂN (PROFILE)
// =====================================================================

// 1. Cập nhật thông tin cơ bản (Tên, SĐT)
router.put('/profile/:id', async (req, res) => {
    const { username, phone } = req.body;
    try {
        await db.promise().query('UPDATE users SET Username = ?, Phone = ? WHERE UserID = ?', [username, phone, req.params.id]);
        res.json({ success: true, message: "Cập nhật thông tin thành công!" });
    } catch (error) {
        res.status(500).json({ error: "Lỗi khi cập nhật thông tin!" });
    }
});

// 2. Upload Avatar
router.post('/profile/:id/avatar', upload.single('avatar'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: "Chưa chọn file ảnh!" });

    try {
        // Tạo đường dẫn ảnh tĩnh để lưu vào DB (Ví dụ: /uploads/avatars/avatar-123.jpg)
        const avatarUrl = `http://192.168.1.2:3000/public/avatars/${req.file.filename}`;

        await db.promise().query('UPDATE users SET Avatar = ? WHERE UserID = ?', [avatarUrl, req.params.id]);
        res.json({ success: true, avatarUrl: avatarUrl, message: "Cập nhật ảnh đại diện thành công!" });
    } catch (error) {
        res.status(500).json({ error: "Lỗi lưu ảnh vào Database!" });
    }
});
// =====================================================================
// API QUẢN LÝ LỊCH CHIẾU (TIMELINE SCHEDULING - REAL DATA)
// =====================================================================

// 1. Lấy toàn bộ dữ liệu khởi tạo (Rạp, Phòng, Phim)
router.get('/showtimes/init-data', async (req, res) => {
    try {
        const [cinemas] = await db.promise().query('SELECT * FROM cinemas WHERE IsDeleted = 0');
        const [rooms] = await db.promise().query('SELECT RoomID, CinemaID, Name, TotalSeats, BufferMinutes FROM rooms');
        const [movies] = await db.promise().query('SELECT id, title, duration, poster_path FROM movies WHERE IsDeleted = 0');
        
        res.json({ cinemas, rooms, movies });
    } catch (error) {
        res.status(500).json({ error: "Lỗi tải dữ liệu khởi tạo lịch chiếu!" });
    }
});

// 2. Lấy danh sách suất chiếu theo Rạp và Ngày
router.get('/showtimes/list', async (req, res) => {
    const { cinemaId, date } = req.query;
    try {
        const sql = `
            SELECT 
                st.ShowtimeID as id, st.RoomID as roomId, st.movie_format as format, 
                st.Price as price, st.Status as status,
                DATE_FORMAT(st.StartTime, '%H:%i') as startTime,
                DATE_FORMAT(st.EndTime, '%H:%i') as endTime,
                m.title as movie, m.duration
            FROM showtimes st
            JOIN movies m ON st.MovieID = m.id
            JOIN rooms r ON st.RoomID = r.RoomID
            WHERE r.CinemaID = ? AND DATE(st.StartTime) = ? AND st.IsDeleted = 0
            ORDER BY st.StartTime ASC
        `;
        const [showtimes] = await db.promise().query(sql, [cinemaId, date]);
        res.json(showtimes);
    } catch (error) {
        res.status(500).json({ error: "Lỗi tải danh sách suất chiếu!" });
    }
});

// 3. Thêm suất chiếu mới (Có kiểm tra trùng lịch)
router.post('/showtimes', async (req, res) => {
    const { movieId, roomId, date, time, format, price } = req.body;

    try {
        const [[movie]] = await db.promise().query('SELECT duration FROM movies WHERE id = ?', [movieId]);
        const [[room]] = await db.promise().query('SELECT BufferMinutes FROM rooms WHERE RoomID = ?', [roomId]);
        
        if (!movie || !room) return res.status(400).json({ error: "Dữ liệu Phim hoặc Phòng không hợp lệ!" });

        const startDateTime = `${date} ${time}:00`;
        
        // Ép kiểu chuẩn xác
        const durationTotal = Number(movie.duration) + Number(room.BufferMinutes || 15); 
        
        const startDateObj = new Date(`${date}T${time}:00`);
        startDateObj.setMinutes(startDateObj.getMinutes() + durationTotal); 
        
        const pad = (n) => n.toString().padStart(2, '0');
        const formattedEndTime = `${startDateObj.getFullYear()}-${pad(startDateObj.getMonth() + 1)}-${pad(startDateObj.getDate())} ${pad(startDateObj.getHours())}:${pad(startDateObj.getMinutes())}:00`;

        // ==========================================
        // 🚨 THÊM LOG ĐỂ KIỂM TRA TERMINAL NODE.JS
        // ==========================================
        console.log("\n=== DEBUG THÊM SUẤT CHIẾU ===");
        console.log(`1. Thời lượng Phim: ${movie.duration}p | Dọn rạp: ${room.BufferMinutes}p`);
        console.log(`2. TỔNG CỘNG TÍNH RA: ${durationTotal} phút`);
        console.log(`3. THỜI GIAN BẮT ĐẦU: ${startDateTime}`);
        console.log(`4. THỜI GIAN KẾT THÚC: ${formattedEndTime}`);
        console.log("===============================\n");

        // Thuật toán kiểm tra Overlap
        const overlapSql = `
            SELECT st.ShowtimeID, st.StartTime, st.EndTime 
            FROM showtimes st
            JOIN movies m ON st.MovieID = m.id
            WHERE st.RoomID = ? 
            AND st.IsDeleted = 0 
            AND m.IsDeleted = 0
            AND (st.StartTime < ? AND st.EndTime > ?)
        `;
        const [conflicts] = await db.promise().query(overlapSql, [roomId, formattedEndTime, startDateTime]);
        if (conflicts.length > 0) {
            console.log("❌ PHÁT HIỆN TRÙNG VỚI CÁC SUẤT SAU TRONG DB:", conflicts);
            return res.status(400).json({ error: `Phòng này đang kẹt lịch chiếu. Đã tính cả thời gian dọn rạp (${room.BufferMinutes}p). Vui lòng chọn giờ khác!` });
        }

        const insertSql = `
            INSERT INTO showtimes (MovieID, RoomID, movie_format, StartTime, EndTime, Price, Status, IsDeleted) 
            VALUES (?, ?, ?, ?, ?, ?, 'scheduled', 0)
        `;
        await db.promise().query(insertSql, [movieId, roomId, format, startDateTime, formattedEndTime, price]);

        res.json({ success: true, message: "Xếp lịch chiếu thành công!" });

    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Lỗi hệ thống khi thêm suất chiếu!" });
    }
});

// 4. Sửa suất chiếu (Có kiểm tra trùng lịch, bỏ qua chính nó)
router.put('/showtimes/:id', async (req, res) => {
    const showtimeId = req.params.id;
    const { movieId, roomId, date, time, format, price } = req.body;

    try {
        const [[movie]] = await db.promise().query('SELECT duration FROM movies WHERE id = ?', [movieId]);
        const [[room]] = await db.promise().query('SELECT BufferMinutes FROM rooms WHERE RoomID = ?', [roomId]);
        
        if (!movie || !room) return res.status(400).json({ error: "Dữ liệu Phim hoặc Phòng không hợp lệ!" });

        const startDateTime = `${date} ${time}:00`;
        const durationTotal = movie.duration + (room.BufferMinutes || 15); 
        
        // Tính toán giờ địa phương (Local Time)
        const startDateObj = new Date(`${date}T${time}:00`);
        startDateObj.setMinutes(startDateObj.getMinutes() + durationTotal); 
        
        const pad = (n) => n.toString().padStart(2, '0');
        const formattedEndTime = `${startDateObj.getFullYear()}-${pad(startDateObj.getMonth() + 1)}-${pad(startDateObj.getDate())} ${pad(startDateObj.getHours())}:${pad(startDateObj.getMinutes())}:00`;

        // KIỂM TRA TRÙNG GIỜ (Loại trừ suất chiếu hiện tại đang sửa)
        const overlapSql = `
            SELECT ShowtimeID FROM showtimes 
            WHERE RoomID = ? AND IsDeleted = 0 AND ShowtimeID != ?
            AND (StartTime < ? AND EndTime > ?)
        `;
        const [conflicts] = await db.promise().query(overlapSql, [roomId, showtimeId, formattedEndTime, startDateTime]);

        if (conflicts.length > 0) {
            return res.status(400).json({ error: `Phòng này đang kẹt lịch chiếu. Đã tính cả thời gian dọn rạp (${room.BufferMinutes}p). Vui lòng chọn giờ khác!` });
        }

        const updateSql = `
            UPDATE showtimes 
            SET MovieID = ?, RoomID = ?, movie_format = ?, StartTime = ?, EndTime = ?, Price = ?
            WHERE ShowtimeID = ?
        `;
        await db.promise().query(updateSql, [movieId, roomId, format, startDateTime, formattedEndTime, price, showtimeId]);

        res.json({ success: true, message: "Cập nhật lịch chiếu thành công!" });

    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Lỗi hệ thống khi cập nhật suất chiếu!" });
    }
});

// 5. Xóa suất chiếu (Soft Delete - Ẩn đi)
router.delete('/showtimes/:id', async (req, res) => {
    const showtimeId = req.params.id;
    try {
        await db.promise().query('UPDATE showtimes SET IsDeleted = 1 WHERE ShowtimeID = ?', [showtimeId]);
        res.json({ success: true, message: "Đã xóa suất chiếu thành công!" });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Lỗi hệ thống khi xóa suất chiếu!" });
    }
});

// =====================================================================
// QUẢN LÝ PHÒNG CHIẾU (ROOMS) - KÈM AUTO ĐÚC GHẾ
// =====================================================================
router.get('/rooms', async (req, res) => {
    try {
        const sql = `
            SELECT r.*, c.Name as CinemaName 
            FROM rooms r 
            JOIN cinemas c ON r.CinemaID = c.id 
            ORDER BY c.id ASC, r.Name ASC
        `;
        const [rooms] = await db.promise().query(sql);
        res.json(rooms);
    } catch (error) {
        res.status(500).json({ error: "Lỗi lấy danh sách phòng!" });
    }
});

router.post('/rooms', async (req, res) => {
    const { cinemaId, name, totalSeats, bufferMinutes } = req.body;
    const capacity = parseInt(totalSeats) || 150;
    
    try {
        // A. Thêm Phòng vào DB
        const insertRoomSql = "INSERT INTO rooms (CinemaID, Name, TotalSeats, BufferMinutes) VALUES (?, ?, ?, ?)";
        const [result] = await db.promise().query(insertRoomSql, [cinemaId, name, capacity, bufferMinutes || 10]);
        const newRoomId = result.insertId;

        // B. Thuật toán: Lập tức "xây" ghế cho phòng vừa tạo
        const seatValues = [];
        const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const seatsPerRow = capacity >= 200 ? 16 : 14; 
        let count = 0;

        for (let r = 0; r < 26; r++) {
            for (let c = 1; c <= seatsPerRow; c++) {
                if (count >= capacity) break;
                
                let seatType = 1; // Ghế thường
                if (count > capacity * 0.4) seatType = 2; // Ghế VIP
                if (count > capacity * 0.85) seatType = 3; // Ghế Sweetbox

                seatValues.push([newRoomId, `${letters[r]}${c}`, seatType]);
                count++;
            }
            if (count >= capacity) break;
        }

        if (seatValues.length > 0) {
            await db.promise().query("INSERT INTO seats (RoomID, SeatNumber, SeatTypeID) VALUES ?", [seatValues]);
        }

        res.json({ 
            success: true, 
            message: `Thêm phòng và đúc sẵn ${count} ghế thành công!`,
            insertId: newRoomId });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Lỗi khi thêm phòng chiếu!" });
    }
});

router.delete('/rooms/:id', async (req, res) => {
    try {
        await db.promise().query("DELETE FROM seats WHERE RoomID = ?", [req.params.id]);
        await db.promise().query("DELETE FROM rooms WHERE RoomID = ?", [req.params.id]);
        res.json({ success: true, message: "Đã xóa phòng và toàn bộ ghế!" });
    } catch (error) {
        res.status(500).json({ error: "Phòng này đã có dữ liệu lịch chiếu, không thể xóa!" });
    }
});

// =====================================================================
// API LƯU SƠ ĐỒ GHẾ VÀ ĐỒNG BỘ XUỐNG BẢNG SEATS (CHO APP FLUTTER ĐỌC)
// =====================================================================
router.put('/rooms/:id/layout', async (req, res) => {
    const roomId = req.params.id;
    const { layoutData } = req.body; 

    try {
        const layoutArray = JSON.parse(layoutData);
        let totalSeats = 0;
        const seatValues = [];

        // 1. Quét chuỗi JSON, đếm sức chứa và bóc tách từng cái ghế thật
        layoutArray.forEach(row => {
            row.seats.forEach(seat => {
                if (seat.type !== 0 && !seat.isSpace) {
                    totalSeats++;
                    // [RoomID, SeatNumber, SeatTypeID]
                    seatValues.push([roomId, seat.id, seat.type]);
                }
            });
        });

        // 2. Cập nhật Layout JSON và Sức chứa mới vào bảng rooms
        await db.promise().query('UPDATE rooms SET LayoutData = ?, TotalSeats = ? WHERE RoomID = ?', [layoutData, totalSeats, roomId]);

        // 3. ĐỒNG BỘ BẢNG SEATS: Tạm tắt khóa ngoại -> Xóa ghế cũ -> Chèn ghế mới
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 0");
        await db.promise().query('DELETE FROM seats WHERE RoomID = ?', [roomId]);
        
        if (seatValues.length > 0) {
            await db.promise().query('INSERT INTO seats (RoomID, SeatNumber, SeatTypeID) VALUES ?', [seatValues]);
        }
        await db.promise().query("SET FOREIGN_KEY_CHECKS = 1");

        res.status(200).json({ success: true, message: `Đã lưu sơ đồ và đồng bộ ${totalSeats} ghế vật lý!` });
    } catch (error) {
        console.error("❌ LỖI LƯU SƠ ĐỒ GHẾ VÀO DB:", error);
        res.status(500).json({ error: "Lỗi lưu sơ đồ máy chủ!" });
    }
});


// =====================================================================
// API: CẬP NHẬT THÔNG TIN RẠP
// =====================================================================
router.put('/cinemas/:id', async (req, res) => {
    const cinemaId = req.params.id;
    const { name, address, brand_id, city_id, latitude, longitude } = req.body;
    
    try {
        const sql = `
            UPDATE cinemas 
            SET name = ?, address = ?, brand_id = ?, city_id = ?, Latitude = ?, Longitude = ? 
            WHERE id = ?
        `;
        await db.promise().query(sql, [
            name, 
            address || '', 
            brand_id || null, 
            city_id || null, 
            latitude || null, 
            longitude || null, 
            cinemaId
        ]);
        res.json({ success: true, message: "Cập nhật rạp thành công!" });
    } catch (error) {
        console.error("❌ Lỗi sửa rạp:", error);
        res.status(500).json({ error: "Lỗi server khi sửa rạp" });
    }
});

// =====================================================================
// API: LẤY DANH SÁCH THƯƠNG HIỆU RẠP (BRANDS)
// =====================================================================
router.get('/brands', async (req, res) => {
    try {
        const [brands] = await db.promise().query('SELECT brand_id, brand_name FROM brands');
        res.json(brands);
    } catch (error) {
        console.error("Lỗi lấy danh sách thương hiệu:", error);
        res.status(500).json({ error: "Lỗi server khi lấy danh sách thương hiệu" });
    }
});

// =====================================================================
// API: THÊM RẠP MỚI
// =====================================================================
router.post('/cinemas', async (req, res) => {
    const { name, address, brand_id, city_id, latitude, longitude, rating } = req.body;
    try {
        const sql = `
            INSERT INTO cinemas (name, address, brand_id, city_id, Latitude, Longitude, rating, IsDeleted) 
            VALUES (?, ?, ?, ?, ?, ?, ?, 0)
        `;
        await db.promise().query(sql, [
            name, address || '', brand_id || 1, city_id || 1, 
            latitude || null, longitude || null, rating || 5.0
        ]);
        res.json({ success: true, message: "Thêm rạp thành công!" });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server khi thêm rạp" });
    }
});

// =====================================================================
// API: CẬP NHẬT RẠP
// =====================================================================
router.put('/cinemas/:id', async (req, res) => {
    const cinemaId = req.params.id;
    const { name, address, brand_id, city_id, latitude, longitude, rating } = req.body;
    try {
        const sql = `
            UPDATE cinemas 
            SET name = ?, address = ?, brand_id = ?, city_id = ?, Latitude = ?, Longitude = ?, rating = ?
            WHERE id = ?
        `;
        await db.promise().query(sql, [
            name, address || '', brand_id || null, city_id || null, 
            latitude || null, longitude || null, rating || 5.0, cinemaId
        ]);
        res.json({ success: true, message: "Cập nhật rạp thành công!" });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server khi sửa rạp" });
    }
});

// =====================================================================
// API: LẤY DANH SÁCH LOẠI GHẾ (ĐỂ RENDER CỌ VẼ ĐỘNG TRÊN ADMIN)
// =====================================================================
router.get('/seattypes', async (req, res) => {
    try {
        const sql = `
            SELECT SeatTypeID, TypeName, WidthSlots, ColorCode 
            FROM seattypes 
            WHERE IsActive = 1 
            ORDER BY SeatTypeID ASC
        `;
        const [types] = await db.promise().query(sql);
        res.json(types);
    } catch (error) {
        console.error("❌ Lỗi lấy danh sách loại ghế:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =====================================================================
// THÊM LOẠI GHẾ MỚI
// =====================================================================
router.post('/seattypes', async (req, res) => {
    const { TypeName, WidthSlots, ColorCode } = req.body;
    try {
        await db.promise().query(
            'INSERT INTO seattypes (TypeName, WidthSlots, ColorCode, IsActive) VALUES (?, ?, ?, 1)', 
            [TypeName, WidthSlots, ColorCode]
        );
        res.json({ success: true, message: "Thêm loại ghế thành công!" });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =====================================================================
// CẬP NHẬT (SỬA) LOẠI GHẾ
// =====================================================================
router.put('/seattypes/:id', async (req, res) => {
    const { TypeName, WidthSlots, ColorCode } = req.body;
    try {
        await db.promise().query(
            'UPDATE seattypes SET TypeName = ?, WidthSlots = ?, ColorCode = ? WHERE SeatTypeID = ?', 
            [TypeName, WidthSlots, ColorCode, req.params.id]
        );
        res.json({ success: true, message: "Cập nhật thành công!" });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =====================================================================
// ẨN LOẠI GHẾ (SOFT DELETE) - KHÔNG XÓA HẲN ĐỂ TRÁNH LỖI HÓA ĐƠN CŨ
// =====================================================================
router.delete('/seattypes/:id', async (req, res) => {
    try {
        await db.promise().query('UPDATE seattypes SET IsActive = 0 WHERE SeatTypeID = ?', [req.params.id]);
        res.json({ success: true, message: "Đã ẩn loại ghế này!" });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =====================================================================
// API: QUẢN LÝ THỂ LOẠI (GENRES)
// =====================================================================
router.get('/genres', async (req, res) => {
    try {
        const [genres] = await db.promise().query('SELECT * FROM genres ORDER BY GenreID DESC');
        res.json(genres);
    } catch (error) { res.status(500).json({ error: "Lỗi server" }); }
});

router.post('/genres', async (req, res) => {
    try {
        await db.promise().query('INSERT INTO genres (GenreName) VALUES (?)', [req.body.GenreName]);
        res.json({ success: true, message: "Thêm thể loại thành công!" });
    } catch (error) { res.status(500).json({ error: "Lỗi server" }); }
});

router.put('/genres/:id', async (req, res) => {
    try {
        await db.promise().query('UPDATE genres SET GenreName = ? WHERE GenreID = ?', [req.body.GenreName, req.params.id]);
        res.json({ success: true, message: "Sửa thể loại thành công!" });
    } catch (error) { res.status(500).json({ error: "Lỗi server" }); }
});

router.delete('/genres/:id', async (req, res) => {
    try {
        await db.promise().query('DELETE FROM moviegenres WHERE GenreID = ?', [req.params.id]); // Xóa khóa ngoại trước
        await db.promise().query('DELETE FROM genres WHERE GenreID = ?', [req.params.id]);
        res.json({ success: true, message: "Xóa thể loại thành công!" });
    } catch (error) { res.status(500).json({ error: "Vướng dữ liệu phim!" }); }
});

// =====================================================================
// API: QUẢN LÝ DIỄN VIÊN (ACTORS)
// =====================================================================
router.get('/actors', async (req, res) => {
    try {
        const [actors] = await db.promise().query('SELECT * FROM actors ORDER BY ActorID DESC');
        res.json(actors);
    } catch (error) { res.status(500).json({ error: "Lỗi server" }); }
});

router.post('/actors', upload.single('avatar_file'), async (req, res) => {
    const { Name, Avatar } = req.body;
    // ✅ SỬA Ở ĐÂY: Lưu đúng thư mục /public/avatars/
    const finalAvatar = req.file ? `/public/avatars/${req.file.filename}` : (Avatar || '');
    try {
        await db.promise().query('INSERT INTO actors (Name, Avatar) VALUES (?, ?)', [Name, finalAvatar]);
        res.json({ success: true, message: "Thêm diễn viên thành công!" });
    } catch (error) { res.status(500).json({ error: "Lỗi server" }); }
});

router.put('/actors/:id', upload.single('avatar_file'), async (req, res) => {
    const { Name, Avatar } = req.body;
    // ✅ SỬA Ở ĐÂY: Lưu đúng thư mục /public/avatars/
    const finalAvatar = req.file ? `/public/avatars/${req.file.filename}` : (Avatar || '');
    try {
        await db.promise().query('UPDATE actors SET Name = ?, Avatar = ? WHERE ActorID = ?', [Name, finalAvatar, req.params.id]);
        res.json({ success: true, message: "Sửa diễn viên thành công!" });
    } catch (error) { res.status(500).json({ error: "Lỗi server" }); }
});

router.delete('/actors/:id', async (req, res) => {
    try {
        await db.promise().query('DELETE FROM movieactors WHERE ActorID = ?', [req.params.id]); // Xóa khóa ngoại trước
        await db.promise().query('DELETE FROM actors WHERE ActorID = ?', [req.params.id]);
        res.json({ success: true, message: "Xóa diễn viên thành công!" });
    } catch (error) { res.status(500).json({ error: "Vướng dữ liệu phim!" }); }
});

// =========================================================================
// API 1: LẤY DANH SÁCH TOÀN BỘ ĐƠN HÀNG (CÓ CHỨA YÊU CẦU HOÀN TIỀN)
// =========================================================================
router.get('/orders', async (req, res) => {
try {
        const sql = `
            SELECT 
                b.BookingID, 
                b.TotalAmount, 
                b.Status, 
                DATE_FORMAT(b.CreatedAt, '%H:%i - %d/%m/%Y') AS OrderDate,
                u.Username, 
                u.Email,
                m.title AS MovieTitle,
                c.Name AS CinemaName,
                r.Name AS RoomName,
                DATE_FORMAT(st.StartTime, '%H:%i %d/%m') AS Showtime,
                
                -- Lấy danh sách ghế (nếu có)
                (SELECT GROUP_CONCAT(s2.SeatNumber SEPARATOR ', ') 
                 FROM bookingseats bs2 JOIN seats s2 ON bs2.SeatID = s2.SeatID 
                 WHERE bs2.BookingID = b.BookingID) AS Seats,
                 
                -- 🚀 LẤY DANH SÁCH BẮP NƯỚC & SỐ LƯỢNG (Ví dụ: "Popcorn Phô Mai (x2), Pepsi (x1)")
                (SELECT GROUP_CONCAT(CONCAT(f.Name, ' (x', bf.Quantity, ')') SEPARATOR ' • ') 
                 FROM bookingfoods bf JOIN foods f ON bf.FoodID = f.FoodID 
                 WHERE bf.BookingID = b.BookingID) AS Foods,
                 
                -- Lấy lý do hoàn tiền (nếu có)
                (SELECT Reason FROM refunds rf WHERE rf.BookingID = b.BookingID ORDER BY CreatedAt DESC LIMIT 1) AS RefundReason
                
            FROM bookings b
            JOIN users u ON b.UserID = u.UserID
            -- 🚀 CHUYỂN THÀNH LEFT JOIN: Nếu khách chỉ mua bắp nước (ShowtimeID = null) thì đơn vẫn không bị biến mất
            LEFT JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            LEFT JOIN movies m ON st.MovieID = m.id
            LEFT JOIN rooms r ON st.RoomID = r.RoomID
            -- Lấy tên rạp: Ưu tiên lấy từ phòng chiếu, nếu không có phòng chiếu thì lấy từ cột CinemaID của Booking
            LEFT JOIN cinemas c ON c.id = COALESCE(r.CinemaID, b.CinemaID)
            ORDER BY b.CreatedAt DESC
        `;
        const [orders] = await db.promise().query(sql);
        res.json(orders);
    } catch (error) {
        console.error("Lỗi lấy danh sách đơn hàng:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =========================================================================
// API 2: XỬ LÝ YÊU CẦU HOÀN TIỀN (DUYỆT HOẶC TỪ CHỐI)
// =========================================================================
router.put('/orders/refund/:bookingId', async (req, res) => {
    const bookingId = req.params.bookingId;
    const { action } = req.body; // action = 'approve' hoặc 'reject'

    try {
        if (action === 'approve') {
            // 1. Cập nhật trạng thái Booking thành Đã hoàn tiền
            await db.promise().query(`UPDATE bookings SET Status = 'Refunded' WHERE BookingID = ?`, [bookingId]);
            // 2. Cập nhật bảng Refunds
            await db.promise().query(`UPDATE refunds SET Status = 'Approved', RefundStatus = 'success', ApprovedAt = NOW() WHERE BookingID = ?`, [bookingId]);
            // 3. Giải phóng ghế (Để người khác có thể mua lại)
            await db.promise().query(`UPDATE bookingseats SET Status = 'Cancelled' WHERE BookingID = ?`, [bookingId]);
            
            res.json({ success: true, message: "Đã DUYỆT hoàn tiền và giải phóng ghế!" });
        } 
        else if (action === 'reject') {
            // 1. Trả Booking về trạng thái Đã thanh toán (Paid)
            await db.promise().query(`UPDATE bookings SET Status = 'Paid' WHERE BookingID = ?`, [bookingId]);
            // 2. Cập nhật bảng Refunds
            await db.promise().query(`UPDATE refunds SET Status = 'Rejected', RefundStatus = 'failed', ApprovedAt = NOW() WHERE BookingID = ?`, [bookingId]);
            
            res.json({ success: true, message: "Đã TỪ CHỐI hoàn tiền. Vé vẫn giữ nguyên." });
        }
    } catch (error) {
        console.error("Lỗi xử lý hoàn tiền:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// =====================================================================
// API QUẢN LÝ BẮP NƯỚC (FOODS & BEVERAGES) - ĐÃ KHỚP DB MỚI
// =====================================================================

// 1. LẤY DANH SÁCH BẮP NƯỚC
router.get('/foods', async (req, res) => {
    try {
        const [foods] = await db.promise().query('SELECT * FROM foods ORDER BY FoodID DESC');
        res.json(foods);
    } catch (error) {
        console.error("Lỗi lấy danh sách bắp nước:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 2. THÊM MỚI BẮP NƯỚC
router.post('/foods', upload.single('food_file'), async (req, res) => {
    // Nhận đúng tên cột từ Frontend gửi lên
    const { Name, Price, description, Type, brand_id } = req.body;
    let ImageURL = req.body.ImageURL || '';

    if (req.file) {
        // 🚀 Bỏ chữ /uploads đi để khớp với thư mục con đã tạo
        ImageURL = `/public/foods/${req.file.filename}`;
    }

    try {
        const sql = 'INSERT INTO foods (Name, Price, description, ImageURL, Type, brand_id) VALUES (?, ?, ?, ?, ?, ?)';
        await db.promise().query(sql, [
            Name, Number(Price), description || '', ImageURL, 
            Type || 'SINGLE', Number(brand_id) || 1
        ]);
        res.json({ success: true, message: "Thêm bắp nước thành công!" });
    } catch (error) {
        console.error("Lỗi thêm bắp nước:", error);
        res.status(500).json({ error: "Lỗi server khi lưu bắp nước" });
    }
});

// 3. CẬP NHẬT BẮP NƯỚC
router.put('/foods/:id', upload.single('food_file'), async (req, res) => {
    const foodId = req.params.id;
    const { Name, Price, description, Type, brand_id } = req.body;
    let ImageURL = req.body.ImageURL || '';

    if (req.file) {
        // 🚀 Bỏ chữ /uploads đi để khớp với thư mục con đã tạo
        ImageURL = `/public/foods/${req.file.filename}`;
    }

    try {
        const sql = 'UPDATE foods SET Name=?, Price=?, description=?, ImageURL=?, Type=?, brand_id=? WHERE FoodID=?';
        await db.promise().query(sql, [
            Name, Number(Price), description || '', ImageURL, 
            Type, Number(brand_id), foodId
        ]);
        res.json({ success: true, message: "Cập nhật thành công!" });
    } catch (error) {
        console.error("Lỗi sửa bắp nước:", error);
        res.status(500).json({ error: "Lỗi server khi cập nhật" });
    }
});

// 4. XÓA BẮP NƯỚC
router.delete('/foods/:id', async (req, res) => {
    try {
        await db.promise().query('DELETE FROM foods WHERE FoodID=?', [req.params.id]);
        res.json({ success: true, message: "Đã xóa mặt hàng bắp nước!" });
    } catch (error) {
        console.error("Lỗi xóa bắp nước:", error);
        res.status(400).json({ error: "Sản phẩm đang có trong hóa đơn của khách, không thể xóa vĩnh viễn!" });
    }
});

// =====================================================================
// API QUẢN LÝ MÃ KHUYẾN MÃI (VOUCHERS) - CHUẨN DATABASE THỰC TẾ
// =====================================================================

// 1. LẤY DANH SÁCH VOUCHERS
router.get('/vouchers', async (req, res) => {
    try {
        const [vouchers] = await db.promise().query('SELECT * FROM vouchers ORDER BY ExpiredAt DESC');
        res.json(vouchers);
    } catch (error) {
        console.error("Lỗi lấy danh sách Voucher:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 2. THÊM VOUCHER MỚI
router.post('/vouchers', async (req, res) => {
    const { Code, DiscountPercent, MinOrderValue, MaxDiscountAmount, ExpiredAt, Quantity } = req.body;
    try {
        const sql = 'INSERT INTO vouchers (Code, DiscountPercent, MinOrderValue, MaxDiscountAmount, ExpiredAt, Quantity) VALUES (?, ?, ?, ?, ?, ?)';
        await db.promise().query(sql, [
            Code, Number(DiscountPercent), Number(MinOrderValue), 
            Number(MaxDiscountAmount), ExpiredAt, Number(Quantity)
        ]);
        res.json({ success: true, message: "Thêm mã khuyến mãi thành công!" });
    } catch (error) {
        console.error("Lỗi thêm Voucher:", error);
        if (error.code === 'ER_DUP_ENTRY') return res.status(400).json({ error: "Mã code này đã tồn tại!" });
        res.status(500).json({ error: "Lỗi server khi lưu voucher" });
    }
});

// 3. SỬA VOUCHER
router.put('/vouchers/:id', async (req, res) => {
    const { Code, DiscountPercent, MinOrderValue, MaxDiscountAmount, ExpiredAt, Quantity } = req.body;
    try {
        const sql = 'UPDATE vouchers SET Code=?, DiscountPercent=?, MinOrderValue=?, MaxDiscountAmount=?, ExpiredAt=?, Quantity=? WHERE VoucherID=?';
        await db.promise().query(sql, [
            Code, Number(DiscountPercent), Number(MinOrderValue), 
            Number(MaxDiscountAmount), ExpiredAt, Number(Quantity), req.params.id
        ]);
        res.json({ success: true, message: "Cập nhật mã khuyến mãi thành công!" });
    } catch (error) {
        console.error("Lỗi sửa Voucher:", error);
        res.status(500).json({ error: "Lỗi server khi cập nhật" });
    }
});

// 4. XÓA VOUCHER
router.delete('/vouchers/:id', async (req, res) => {
    try {
        await db.promise().query('DELETE FROM vouchers WHERE VoucherID=?', [req.params.id]);
        res.json({ success: true, message: "Đã xóa mã khuyến mãi!" });
    } catch (error) {
        console.error("Lỗi xóa Voucher:", error);
        // Bắt lỗi khóa ngoại bảng uservouchers
        res.status(400).json({ error: "Voucher này đã được người dùng lưu vào ví, không thể xóa vĩnh viễn!" });
    }
});

// =====================================================================
// API QUẢN LÝ BÀI VIẾT & BÌNH LUẬN (SOCIAL MODERATION)
// =====================================================================

// 1. Lấy danh sách Bài viết (Kèm User, Hình ảnh, Like, Comment, VÀ SỐ LƯỢNG BÁO CÁO)
router.get('/posts', async (req, res) => {
    try {
        const sql = `
            SELECT 
                p.PostID, p.Content, p.Type, p.CreatedAt, p.BgColor, p.Status, 
                p.PostImages AS Images, /* 🚀 SỬA Ở ĐÂY: Lấy trực tiếp cột PostImages trong bảng posts */
                p.UserID,
                u.UserName, 
                u.Avatar,
                (SELECT COUNT(*) FROM post_likes pl WHERE pl.PostID = p.PostID) AS LikeCount,
                (SELECT COUNT(*) FROM comments c WHERE c.PostID = p.PostID) AS CommentCount,
                (SELECT COUNT(*) FROM post_reports pr WHERE pr.PostID = p.PostID) AS ReportCount
            FROM posts p
            LEFT JOIN users u ON p.UserID = u.UserID
            ORDER BY p.CreatedAt DESC
        `;
        const [posts] = await db.promise().query(sql);
        res.json(posts);
    } catch (error) {
        console.error("Lỗi lấy danh sách bài viết:", error);
        res.status(500).json({ error: "Lỗi server" });
    }
});

// 2. Lấy danh sách Bình luận của 1 Bài viết cụ thể
// =======================================================================
// API: ADMIN LẤY DANH SÁCH BÌNH LUẬN CỦA 1 BÀI VIẾT (ĐÃ KÈM AVATAR VÀ TÊN)
// =======================================================================
router.get('/posts/:id/comments', async (req, res) => {
    const postId = req.params.id;

    try {
        // 🚀 ĐÃ SỬA: Thay "ten_bang_comment_cua_con" bằng tên bảng đúng trong MySQL!
        const query = `
            SELECT 
                c.*, 
                u.Username AS UserName, 
                u.Avatar AS Avatar 
            FROM comments c
            LEFT JOIN users u ON c.UserID = u.UserID
            WHERE c.PostID = ?
            ORDER BY c.CreatedAt DESC
        `;
        
        const [comments] = await db.promise().query(query, [postId]);
        
        res.json(comments);
    } catch (error) {
        console.error("Lỗi lấy danh sách bình luận:", error);
        res.status(500).json({ error: "Lỗi hệ thống" });
    }
});

// 3. Xóa Bài viết (Admin gỡ bài vi phạm)
// =====================================================================
// XÓA BÀI VIẾT & THI HÀNH XỬ PHẠT NGƯỜI DÙNG (MODERATION)
// =====================================================================
router.delete('/posts/:id', async (req, res) => {
    const postId = req.params.id;
    // Nhận dữ liệu hình phạt từ UI Admin gửi xuống
    const penaltyType = req.body.penaltyType; // 'WARN', 'MUTE_7', hoặc 'BAN'
    const userId = req.body.userId;

    // Sử dụng Transaction để đảm bảo: Xóa bài và Khóa User phải diễn ra đồng thời
    const connection = await db.promise().getConnection();
    try {
        await connection.beginTransaction();

        // 1. Dọn dẹp rác liên quan đến bài viết trước (Tránh lỗi khóa ngoại)
        await connection.query('DELETE FROM post_likes WHERE PostID = ?', [postId]);
        await connection.query('DELETE FROM comment_likes WHERE CommentID IN (SELECT CommentID FROM comments WHERE PostID = ?)', [postId]);
        await connection.query('DELETE FROM comments WHERE PostID = ?', [postId]);
        await connection.query('DELETE FROM postimages WHERE PostID = ?', [postId]);
        await connection.query('DELETE FROM post_reports WHERE PostID = ?', [postId]); // Xóa cả báo cáo
        
        // 2. Xóa bài viết chính
        await connection.query('DELETE FROM posts WHERE PostID = ?', [postId]);

        // 3. Thi hành án phạt lên User
        if (userId && penaltyType) {
            if (penaltyType === 'MUTE_7') {
                // Cấm 7 ngày: Đổi isLocked = 1, Set UnlockTime = Hiện tại + 7 ngày
                const unlockTime = new Date();
                unlockTime.setDate(unlockTime.getDate() + 7);
                await connection.query('UPDATE users SET isLocked = 1, UnlockTime = ? WHERE UserID = ?', [unlockTime, userId]);
                
            } else if (penaltyType === 'BAN') {
                // Khóa vĩnh viễn: Đổi isLocked = 1, UnlockTime = Năm 2099 (hoặc NULL tùy logic hệ thống con)
                const forever = new Date('2099-12-31');
                await connection.query('UPDATE users SET isLocked = 1, UnlockTime = ? WHERE UserID = ?', [forever, userId]);
            }
            // Nếu là 'WARN' (Cảnh cáo) thì chỉ xóa bài (bước 2) chứ không khóa tài khoản.
        }

        await connection.commit(); // Xác nhận lưu toàn bộ thay đổi
        res.json({ success: true, message: "Đã thi hành xét duyệt thành công!" });

    } catch (error) {
        await connection.rollback(); // Nếu có lỗi ở bất kỳ bước nào, hoàn tác lại toàn bộ (Bảo vệ dữ liệu)
        console.error("Lỗi khi xét duyệt bài:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi xử phạt!" });
    } finally {
        connection.release();
    }
});
router.put('/posts/:id/ignore-reports', async (req, res) => {
    const postId = req.params.id;

    try {
        // Chỉ cần xóa sạch lịch sử báo cáo của bài viết này trong bảng post_reports
        // (Khi ReportCount về 0, nó sẽ tự động biến mất khỏi Tab "Chờ xử lý vi phạm" trên React)
        await db.promise().query(
            'DELETE FROM post_reports WHERE PostID = ?', 
            [postId]
        );

        res.json({ success: true, message: "Đã xóa các báo cáo. Bài viết hợp lệ." });
    } catch (error) {
        console.error("Lỗi bỏ qua báo cáo:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi xử lý báo cáo" });
    }
});

// 4. Xóa một Bình luận vi phạm
router.delete('/comments/:id', async (req, res) => {
    try {
        await db.promise().query('DELETE FROM comment_likes WHERE CommentID = ?', [req.params.id]);
        await db.promise().query('DELETE FROM comments WHERE CommentID = ?', [req.params.id]);
        res.json({ success: true, message: "Đã gỡ bình luận!" });
    } catch (error) {
        console.error("Lỗi xóa bình luận:", error);
        res.status(500).json({ error: "Không thể xóa bình luận" });
    }
});

module.exports = router;