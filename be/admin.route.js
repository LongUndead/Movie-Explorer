// File: admin.route.js
const express = require('express');
const router = express.Router();
const axios = require('axios'); // Thêm cái này vì cào phim cần dùng axios
const db = require('./db'); // Import DB dùng chung
const bcrypt = require('bcryptjs'); // Bắt buộc phải có để so sánh mật khẩu
const multer = require('multer');
const path = require('path');
const fs = require('fs');


const { Groq } = require('groq-sdk');
// Nhớ thay API_KEY thật của ông vào nhé! (Hoặc lấy từ process.env)
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });
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
        // 1. TỔNG DOANH THU THỰC TẾ (Dùng LEFT JOIN để không sót đơn bắp nước lẻ)
        const statsSql = `
            SELECT SUM(b.TotalAmount) as totalRevenue
            FROM bookings b
            LEFT JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            LEFT JOIN rooms r ON st.RoomID = r.RoomID
            WHERE b.Status = 'Paid' ${filterStr}
        `;
        
        // 2. DOANH THU VÉ & TỔNG VÉ (Vé thì bắt buộc phải có showtime nên JOIN bình thường)
        const ticketSql = `
            SELECT COUNT(bs.SeatID) as totalTickets, SUM(bs.Price) as ticketRevenue
            FROM bookingseats bs
            JOIN bookings b ON bs.BookingID = b.BookingID
            JOIN showtimes st ON bs.ShowtimeID = st.ShowtimeID
            JOIN rooms r ON st.RoomID = r.RoomID
            WHERE b.Status = 'Paid' ${filterStr}
        `;

        // 3. DOANH THU BẮP NƯỚC (Dùng LEFT JOIN)
        const foodSql = `
            SELECT SUM(f.Price * bf.Quantity) as foodRevenue
            FROM bookingfoods bf
            JOIN foods f ON bf.FoodID = f.FoodID
            JOIN bookings b ON bf.BookingID = b.BookingID
            LEFT JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            LEFT JOIN rooms r ON st.RoomID = r.RoomID
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

        // 5. GIAO DỊCH GẦN ĐÂY (Dùng LEFT JOIN để hiển thị cả "Đơn thức ăn tại quầy")
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
            LEFT JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            LEFT JOIN movies m ON st.MovieID = m.id
            LEFT JOIN rooms r ON st.RoomID = r.RoomID
            WHERE 1=1 ${filterStr}
            ORDER BY b.CreatedAt DESC
            LIMIT 10
        `;

       // 6. TOP 5 BẮP NƯỚC BÁN CHẠY NHẤT (Dùng LEFT JOIN + Trả lại tên cột ImageURL)
        const topFoodsSql = `
            SELECT 
                f.Name as name, 
                f.ImageURL as image,  /* 🚀 ĐÃ TRẢ LẠI ĐÚNG TÊN CỘT ImageURL CỦA ÔNG */
                f.brand_id as brandId, 
                SUM(bf.Quantity) as quantity, 
                SUM(f.Price * bf.Quantity) as revenue
            FROM bookingfoods bf
            JOIN foods f ON bf.FoodID = f.FoodID
            JOIN bookings b ON bf.BookingID = b.BookingID
            LEFT JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
            LEFT JOIN rooms r ON st.RoomID = r.RoomID
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
            warningFilterStr += " AND DATE(st.StartTime) = ? "; 
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
            warningShowtimes: warningRes || [] 
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
        // 1. DỌN DẸP THÔNG MINH (BẢO TOÀN LỊCH SỬ NGƯỜI DÙNG)
        // =========================================================================
        await db.promise().query("TRUNCATE TABLE seatholds");

        // Helper tính số lượng ghế (IMAX/4DX thường ít ghế hơn rạp thường)
        const getExactCapacity = (cinemaName, roomIndex) => {
            if (roomIndex === 3) return 100; // Phòng 4DX ít ghế do cấu trúc rung lắc
            if (roomIndex === 2) return 250; // Phòng IMAX rộng hơn
            
            const name = cinemaName.toLowerCase();
            if (name.includes('cgv')) return 182;
            if (name.includes('lotte')) return 230;
            if (name.includes('galaxy')) return 220;
            if (name.includes('bhd')) return 219;
            if (name.includes('cinestar')) return 200;
            if (name.includes('mega gs') || name.includes('megags')) return 210;
            return 150; 
        };

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
        // 2. KHỞI TẠO PHÒNG CHIẾU (QUY HOẠCH IMAX & 4DX)
        // =========================================================================
        const [cinemas] = await db.promise().query("SELECT id, name FROM cinemas");
        const [roomCounts] = await db.promise().query("SELECT CinemaID, COUNT(*) as count FROM rooms GROUP BY CinemaID");
        
        const roomCountMap = {};
        roomCounts.forEach(r => roomCountMap[r.CinemaID] = r.count);

        const newRooms = [];
        cinemas.forEach(cinema => {
            const currentRooms = roomCountMap[cinema.id] || 0;
            const targetRooms = 5; 
            
            for (let i = currentRooms + 1; i <= targetRooms; i++) {
                let roomLabel = `Rạp ${i}`;
                if (i === 2) roomLabel = `IMAX ${i}`; // Đánh dấu phòng 2 là IMAX
                if (i === 3) roomLabel = `4DX ${i}`;  // Đánh dấu phòng 3 là 4DX
                
                const exactCapacity = getExactCapacity(cinema.name, i); 
                newRooms.push([cinema.id, `${cinema.name} - ${roomLabel}`, exactCapacity, 10]);
            }
        });

        if (newRooms.length > 0) {
            await db.promise().query("INSERT INTO rooms (CinemaID, Name, TotalSeats, BufferMinutes) VALUES ?", [newRooms]);
        }

        // =========================================================================
        // 3. KHỞI TẠO SUẤT CHIẾU (ÉP LUẬT ĐỊNH DẠNG THEO PHÒNG)
        // =========================================================================
        const [movies] = await db.promise().query("SELECT id, COALESCE(duration, 120) as duration FROM movies");
        const [allRoomsFinal] = await db.promise().query("SELECT RoomID, Name, COALESCE(BufferMinutes, 10) as buffer FROM rooms");

        if (movies.length === 0) return res.status(400).json({ error: "Vui lòng chạy sync-movies trước!" });

        const showtimeValues = [];
        const daysToSchedule = 7; 
        const now = new Date();
        let movieIndex = 0; 
        
        // Chỉ random 2D/3D cho các rạp thường
        const normalFormatOptions = ['2D Phụ đề', '2D Lồng Tiếng', '2D Phụ đề', '3D Phụ đề'];

        // 🚀 DỜI HÀM PAD LÊN ĐÂY ĐỂ DÙNG CHUNG CHO CẢ TẠO NGÀY VÀ GIỜ
        const pad = (n) => (n < 10 ? '0' + n : n);

        for (let dayOffset = 0; dayOffset < daysToSchedule; dayOffset++) {
            for (const room of allRoomsFinal) {
                const targetDate = new Date(now);
                targetDate.setDate(now.getDate() + dayOffset);
                
                // 🚀 SỬA LỖI MÚI GIỜ CHÍNH LÀ DÒNG NÀY (Bỏ toISOString)
                const dateString = `${targetDate.getFullYear()}-${pad(targetDate.getMonth() + 1)}-${pad(targetDate.getDate())}`; 
                
                const [existingShows] = await db.promise().query(
                    "SELECT COUNT(*) as count FROM showtimes WHERE RoomID = ? AND DATE(StartTime) = ?", 
                    [room.RoomID, dateString]
                );
                
                if (existingShows[0].count > 0) continue;

                let currentStartTime = new Date(targetDate);
                currentStartTime.setHours(8, 30, 0, 0); 

                const endTimeLimit = new Date(currentStartTime);
                endTimeLimit.setHours(23, 0, 0, 0); 

                // 🌟 LỌC ĐỊNH DẠNG THEO TÊN PHÒNG
                let roomFormat = '';
                if (room.Name.includes('IMAX')) roomFormat = 'IMAX';
                else if (room.Name.includes('4DX')) roomFormat = '4DX';

                while (currentStartTime < endTimeLimit) {
                    const currentMovie = movies[movieIndex % movies.length];
                    movieIndex++; 

                    const isCinetour = Math.random() < 0.1 ? 1 : 0; 
                    
                    const formattedStartTime = `${currentStartTime.getFullYear()}-${pad(currentStartTime.getMonth() + 1)}-${pad(currentStartTime.getDate())} ${pad(currentStartTime.getHours())}:${pad(currentStartTime.getMinutes())}:00`;

                    const endDateTime = new Date(currentStartTime.getTime() + currentMovie.duration * 60000);
                    const formattedEndTime = `${endDateTime.getFullYear()}-${pad(endDateTime.getMonth() + 1)}-${pad(endDateTime.getDate())} ${pad(endDateTime.getHours())}:${pad(endDateTime.getMinutes())}:00`;

                    // Gán định dạng chuẩn cho suất chiếu này
                    const finalFormat = roomFormat ? roomFormat : normalFormatOptions[Math.floor(Math.random() * normalFormatOptions.length)];
                    const finalPrice = getExactPrice(room.Name, finalFormat);

                    showtimeValues.push([currentMovie.id, room.RoomID, formattedStartTime, formattedEndTime, finalPrice, isCinetour, finalFormat]);

                    const totalMinutesToAdd = currentMovie.duration + room.buffer + 10; 
                    currentStartTime.setMinutes(currentStartTime.getMinutes() + totalMinutesToAdd);
                }
            }
        }

        if (showtimeValues.length > 0) {
            await db.promise().query("INSERT INTO showtimes (MovieID, RoomID, StartTime, EndTime, Price, cinetour, movie_format) VALUES ?", [showtimeValues]);
        }

        // =========================================================================
        // 4. KHỞI TẠO GHẾ (CÓ VÙNG TRUNG TÂM CHO RẠP THƯỜNG + ĐẶC BIỆT CHO IMAX/4DX)
        // =========================================================================
        // Đảm bảo trong DB luôn có sẵn ID loại ghế cho IMAX và 4DX (Trường hợp Admin chưa tạo)
        await db.promise().query(`INSERT IGNORE INTO seattypes (SeatTypeID, TypeName, WidthSlots, ColorCode, IsActive) VALUES (4, 'Ghế IMAX', 1, '#2563eb', 1), (5, 'Ghế 4DX', 1, '#dc2626', 1)`);

        const [roomsToSeat] = await db.promise().query("SELECT RoomID, TotalSeats, Name FROM rooms");
        let totalSeatsInserted = 0;

        for (const room of roomsToSeat) {
            const [existingSeats] = await db.promise().query("SELECT COUNT(*) as count FROM seats WHERE RoomID = ?", [room.RoomID]);
            
            if (existingSeats[0].count > 0) {
                continue; 
            }

            const capacity = room.TotalSeats; 
            const seatValues = [];
            const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
            const seatsPerRow = capacity >= 200 ? 16 : 14; 
            
            // 🚀 BƯỚC TÍNH TOÁN: Tính trước tổng số hàng để biết đâu là hàng cuối cùng
            const totalRows = Math.ceil(capacity / seatsPerRow);
            let count = 0;

            // 🌟 NẾU LÀ PHÒNG IMAX HOẶC 4DX, ĐỔ 100% LOẠI GHẾ TƯƠNG ỨNG
            let forceSeatType = null;
            if (room.Name.includes('IMAX')) forceSeatType = 4; // ID 4 = Ghế IMAX
            if (room.Name.includes('4DX')) forceSeatType = 5;  // ID 5 = Ghế 4DX

            for (let r = 0; r < totalRows; r++) {
                for (let c = 1; c <= seatsPerRow; c++) {
                    if (count >= capacity) break;
                    
                    let seatType = 1; 

                    if (forceSeatType !== null) {
                        seatType = forceSeatType; // Áp đặt 100% ghế đặc biệt (IMAX/4DX)
                    } else {
                        // 🚀 THUẬT TOÁN TẠO VÙNG TRUNG TÂM CHO PHÒNG CHIẾU THƯỜNG 🚀
                        if (r === totalRows - 1) {
                            // 1. Dành riêng Hàng Cuối Cùng cho Ghế Đôi (Couple - Type 3)
                            seatType = 3;
                        } 
                        else if (r >= 3 && r <= totalRows - 3 && c >= 4 && c <= seatsPerRow - 3) {
                            // 2. Vùng Trung Tâm (Ghế VIP - Type 2):
                            // - Bỏ 3 hàng đầu (r < 3) và 2 hàng cuối (r > totalRows - 3)
                            // - Bỏ 3 cột bên trái (c < 4) và 3 cột bên phải (c > seatsPerRow - 3)
                            seatType = 2;
                        } 
                        else {
                            // 3. Những ghế còn lại (Sát màn hình, sát mép tường 2 bên) là Ghế Thường (Type 1)
                            seatType = 1;
                        }
                    }

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

        res.json({ success: true, message: `🔥 ĐÃ SETUP HOÀN HẢO: Cấu trúc riêng rạp IMAX & 4DX. Đúc thêm ${totalSeatsInserted} ghế mới. Tạo ${showtimeValues.length} suất chiếu mới.` });
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
    
    // 🚀 ĐÃ SỬA: Không ghép chuỗi `/uploads/` nữa, chỉ lưu đúng cái tên file gốc do Multer tạo ra
    const finalPoster = req.files && req.files['poster_file'] ? req.files['poster_file'][0].filename : poster_path;
    
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
            // 🚀 ĐÃ SỬA: Chỉ push đúng tên file vào mảng
            backdropArray.push(file.filename);
        });
    }
    const finalBackdrop = backdropArray.length > 0 ? JSON.stringify(backdropArray) : '';

    try {
        const sql = `INSERT INTO movies (title, genres, duration, release_date, language, age_rating, vote_average, overview, poster_path, backdrop_path, TrailerURL, cast, IsDeleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`;
        await db.promise().query(sql, [
            title, genres || '', duration, release_date || null, language, age_rating, vote_average, overview, finalPoster, finalBackdrop, TrailerURL || '', cast || ''
        ]);

        // =======================================================
        // 🚀 AI TỰ ĐỘNG VIẾT CONTENT & BẮN THÔNG BÁO / ĐĂNG BÀI
        // =======================================================
        let aiTitle = '🎬 Phim mới ra mắt'; // Fallback nếu AI lỗi
        let aiContent = `Bom tấn "${title}" đã cập bến. Đặt vé ngay hôm nay!`;

        try {
            // 1. Viết Prompt nắn gân AI cực mạnh
            const isUpcoming = release_date && (new Date(release_date) > new Date());
            const prompt = `
                Bạn là quản trị viên rạp phim. Hãy viết nội dung thông báo ngắn gọn (khoảng 30 chữ) trên App.
                Tên phim: "${title}". Thể loại: ${genres || 'Đang cập nhật'}.
                Trạng thái: ${isUpcoming ? 'Phim sắp ra rạp' : 'Phim đang chiếu'}.
                Yêu cầu bắt buộc:
                - Trả về ĐÚNG định dạng JSON gồm: "title" (tiêu đề siêu ngắn) và "content" (nội dung hấp dẫn, có emoji).
                - Sử dụng tiếng Việt chuẩn 100%. Tuyệt đối KHÔNG chế từ hoặc sai chính tả (Ví dụ: phải viết là "Sắp chiếu" chứ không được viết là "Sắp chức").
            `;

            // 2. Giao việc cho Groq
            const chatCompletion = await groq.chat.completions.create({
                messages: [{ role: "system", content: prompt }],
                model: "llama-3.1-8b-instant",
                temperature: 0.5, // 🚀 HẠ NHIỆT ĐỘ TỪ 0.7 XUỐNG 0.5 ĐỂ AI BỚT BAY BỔNG/CHẾ TỪ
                max_tokens: 150,
                response_format: { type: "json_object" } 
            });

            // 3. Giải mã kết quả
            const aiResponse = JSON.parse(chatCompletion.choices[0]?.message?.content);
            
            // 🚀 LỚP BẢO VỆ THỦ CÔNG: Quét và sửa tự động các từ AI hay viết sai tiếng Việt
            const fixTypo = (text) => {
                if (!text) return text;
                return text
                    .replace(/Sắp Chức/g, 'Sắp Chiếu')
                    .replace(/sắp chức/gi, 'sắp chiếu')
                    .replace(/Sắp rạp/gi, 'Sắp ra rạp');
            };

            if (aiResponse.title) aiTitle = fixTypo(aiResponse.title);
            if (aiResponse.content) aiContent = fixTypo(aiResponse.content);

            // 4. 🔥 TỰ ĐỘNG ĐĂNG LÊN BẢNG TIN (Cộng đồng)
            const botUserId = 1; // ID tài khoản admin

            // Chuẩn bị mảng ảnh cho bài đăng (chỉ chứa poster phim vừa lưu)
            const postImages = JSON.stringify([finalPoster]);
            
            // Nội dung bài đăng kết hợp tiêu đề và nội dung AI
            const finalPostContent = `📢 HOT: ${aiTitle}\n\n${aiContent}`;

            await db.promise().query(
                `INSERT INTO posts (UserID, Content, Type, Status, BgColor, PostImages, CreatedAt) VALUES (?, ?, 'news', 1, '#ffffff', ?, NOW())`,
                [botUserId, finalPostContent, postImages]
            );

        } catch (aiError) {
            console.error("Lỗi AI tạo content hoặc đăng bài:", aiError);
        }

        // 5. Bắn Notification cho toàn bộ User (Dùng AI Content)
        const broadcastMovieSql = `
            INSERT INTO notifications (UserID, Title, Type, Content, IsRead, CreatedAt)
            SELECT UserID, ?, 'MOVIE', ?, 0, NOW()
            FROM users WHERE IsLocked = 0
        `;
        await db.promise().query(broadcastMovieSql, [aiTitle, aiContent]);
        res.json({ success: true, message: "Thêm phim thành công và đã đăng bài cộng đồng!" });
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

// =====================================================================
// 2. API Áp dụng hình phạt Danh sách đen (ĐÃ FIX: BẮN THÔNG BÁO CHO USER)
// =====================================================================
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
        
        // 🚀 CÁC BIẾN ĐỂ BẮN THÔNG BÁO VỀ APP KHÁCH HÀNG
        let notifTitle = "";
        let notifContent = "";

        // LUẬT XỬ PHẠT CỦA BẠN:
        if (refundCount <= 2) {
            message = `⚠️ Đã hoàn vé ${refundCount} lần: Gửi thông báo CẢNH CÁO tới người dùng!`;
            notifTitle = "⚠️ Cảnh báo lạm dụng hoàn vé";
            notifContent = `Bạn đã hủy/hoàn vé ${refundCount} lần. Hệ thống sẽ tự động khóa tài khoản nếu bạn vi phạm quá 3 lần. Xin lưu ý!`;
        } else if (refundCount === 3) {
            isLocked = 1;
            unlockTime = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000); // Cộng 3 ngày
            message = `⛔ Hoàn vé 3 lần: Đã KHÓA TÀI KHOẢN 3 NGÀY!`;
            notifTitle = "⛔ Tài khoản bị tạm khóa (3 Ngày)";
            notifContent = `Bạn đã hoàn vé 3 lần, vi phạm quy định chống lạm dụng. Tài khoản bị khóa đến ${unlockTime.toLocaleDateString('vi-VN')}.`;
        } else if (refundCount === 4) {
            isLocked = 1;
            unlockTime = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000); // Cộng 5 ngày
            message = `⛔ Hoàn vé 4 lần: Đã KHÓA TÀI KHOẢN 5 NGÀY!`;
            notifTitle = "⛔ Tài khoản bị tạm khóa (5 Ngày)";
            notifContent = `Vi phạm lần 4: Hoàn vé quá giới hạn. Tài khoản của bạn bị khóa đến ${unlockTime.toLocaleDateString('vi-VN')}.`;
        } else if (refundCount === 5) {
            isLocked = 1;
            unlockTime = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // Cộng 7 ngày
            message = `⛔ Hoàn vé 5 lần: Đã KHÓA TÀI KHOẢN 7 NGÀY!`;
            notifTitle = "⛔ Tài khoản bị tạm khóa (7 Ngày)";
            notifContent = `Vi phạm lần 5: Lạm dụng hoàn vé nghiêm trọng. Tài khoản bị khóa đến ${unlockTime.toLocaleDateString('vi-VN')}.`;
        } else {
            isLocked = 1;
            unlockTime = null; // Khóa vĩnh viễn
            message = `💀 Hoàn vé ${refundCount} lần: Đã KHÓA VĨNH VIỄN!`;
            notifTitle = "💀 Tài khoản bị khóa vĩnh viễn";
            notifContent = `Bạn đã hoàn vé ${refundCount} lần. Tài khoản của bạn đã bị đưa vào danh sách đen và khóa vĩnh viễn.`;
        }

        // Cập nhật trạng thái khóa
        if (refundCount >= 3) {
            await db.promise().query('UPDATE users SET IsLocked = ?, UnlockTime = ? WHERE UserID = ?', [isLocked, unlockTime, userId]);
        }
        
        // 🚀 BẮN THÔNG BÁO CHO USER BIẾT MÌNH BỊ PHẠT VÌ LÝ DO GÌ
        if (notifTitle !== "") {
            await db.promise().query(
                `INSERT INTO notifications (UserID, Title, Type, Content, IsRead, CreatedAt) VALUES (?, ?, 'BANNED', ?, 0, NOW())`, 
                [userId, notifTitle, notifContent]
            );
        }

        res.json({ success: true, message });
    } catch (error) {
        console.error("Lỗi Blacklist:", error);
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
// API: APP FLUTTER GỌI ĐỂ QUÉT TRẠNG THÁI KHÓA (AUTO-BAN)
// =====================================================================
router.get('/users/:id/check-status', async (req, res) => {
    try {
        const [[user]] = await db.promise().query('SELECT IsLocked, UnlockTime FROM users WHERE UserID = ?', [req.params.id]);
        if (!user) return res.status(404).json({ error: "Không tìm thấy user" });

        // Tự động mở khóa nếu hết hạn (Phòng hờ trường hợp Admin khóa có thời hạn)
        if (user.IsLocked === 1 && user.UnlockTime && new Date(user.UnlockTime) <= new Date()) {
            await db.promise().query('UPDATE users SET IsLocked = 0, UnlockTime = NULL WHERE UserID = ?', [req.params.id]);
            return res.json({ isLocked: false });
        }

        res.json({ isLocked: user.IsLocked === 1 });
    } catch (error) {
        res.status(500).json({ error: "Lỗi server" });
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
    const avatarPath = `avatars/${req.file.filename}`;

    await db.promise().query(
        'UPDATE users SET Avatar = ? WHERE UserID = ?',
        [avatarPath, req.params.id]
    );

    res.json({
        success: true,
        avatarUrl: `http://192.168.1.7:3000/public/${avatarPath}`
    });
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
            WHERE r.CinemaID = ? 
              AND st.IsDeleted = 0
              AND st.StartTime >= CONCAT(?, ' 06:00:00') 
              AND st.StartTime < DATE_ADD(CONCAT(?, ' 06:00:00'), INTERVAL 1 DAY)
            ORDER BY st.StartTime ASC
        `;
        const [showtimes] = await db.promise().query(sql, [cinemaId, date, date]);
        res.json(showtimes);
    } catch (error) {
        res.status(500).json({ error: "Lỗi tải danh sách suất chiếu!" });
    }
});

// 3. Thêm suất chiếu mới (Có kiểm tra trùng lịch và hỗ trợ chiếu qua đêm)
router.post('/showtimes', async (req, res) => {
    const { movieId, roomId, date, time, format, price } = req.body;

    try {
        const [[movie]] = await db.promise().query('SELECT duration FROM movies WHERE id = ?', [movieId]);
        const [[room]] = await db.promise().query('SELECT BufferMinutes FROM rooms WHERE RoomID = ?', [roomId]);
        
        if (!movie || !room) return res.status(400).json({ error: "Dữ liệu Phim hoặc Phòng không hợp lệ!" });

        // 🚀 THUẬT TOÁN TÍNH GIỜ QUA ĐÊM (LATE-NIGHT SCREENINGS)
        const pad = (n) => n.toString().padStart(2, '0');
        
        // 1. Tách giờ và phút từ time (VD: "01:30")
        const [hours, minutes] = time.split(':').map(Number);
        
        // 2. Tạo object Date từ ngày được chọn trên giao diện
        const startDateObj = new Date(`${date}T00:00:00`);
        
        // 3. LOGIC QUA ĐÊM: Nếu giờ chiếu nhỏ hơn 6h sáng, cộng thêm 1 ngày
        if (hours < 6) {
            startDateObj.setDate(startDateObj.getDate() + 1);
        }
        
        // 4. Set giờ và phút chuẩn xác
        startDateObj.setHours(hours, minutes, 0, 0);

        // 5. Chuỗi startDateTime chuẩn để lưu DB và quét trùng
        const startDateTime = `${startDateObj.getFullYear()}-${pad(startDateObj.getMonth() + 1)}-${pad(startDateObj.getDate())} ${pad(startDateObj.getHours())}:${pad(startDateObj.getMinutes())}:00`;

        // 6. Tính giờ kết thúc (EndTime)
        const durationTotal = Number(movie.duration) + Number(room.BufferMinutes || 15); 
        const endDateObj = new Date(startDateObj.getTime()); // Copy từ giờ bắt đầu
        endDateObj.setMinutes(endDateObj.getMinutes() + durationTotal); 
        
        const formattedEndTime = `${endDateObj.getFullYear()}-${pad(endDateObj.getMonth() + 1)}-${pad(endDateObj.getDate())} ${pad(endDateObj.getHours())}:${pad(endDateObj.getMinutes())}:00`;

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

// 4. Sửa suất chiếu (Có kiểm tra trùng lịch, bỏ qua chính nó, hỗ trợ chiếu qua đêm)
router.put('/showtimes/:id', async (req, res) => {
    const showtimeId = req.params.id;
    const { movieId, roomId, date, time, format, price } = req.body;

    try {
        const [[movie]] = await db.promise().query('SELECT duration FROM movies WHERE id = ?', [movieId]);
        const [[room]] = await db.promise().query('SELECT BufferMinutes FROM rooms WHERE RoomID = ?', [roomId]);
        
        if (!movie || !room) return res.status(400).json({ error: "Dữ liệu Phim hoặc Phòng không hợp lệ!" });

        // 🚀 THUẬT TOÁN TÍNH GIỜ QUA ĐÊM (LATE-NIGHT SCREENINGS)
        const pad = (n) => n.toString().padStart(2, '0');
        
        // 1. Tách giờ và phút từ time (VD: "01:30")
        const [hours, minutes] = time.split(':').map(Number);
        
        // 2. Tạo object Date từ ngày được chọn
        const startDateObj = new Date(`${date}T00:00:00`);
        
        // 3. LOGIC QUA ĐÊM: Nếu giờ chiếu nhỏ hơn 6h sáng, cộng thêm 1 ngày
        if (hours < 6) {
            startDateObj.setDate(startDateObj.getDate() + 1);
        }
        
        // 4. Set giờ và phút chuẩn xác
        startDateObj.setHours(hours, minutes, 0, 0);

        // 5. Chuỗi startDateTime chuẩn để lưu DB và quét trùng
        const startDateTime = `${startDateObj.getFullYear()}-${pad(startDateObj.getMonth() + 1)}-${pad(startDateObj.getDate())} ${pad(startDateObj.getHours())}:${pad(startDateObj.getMinutes())}:00`;

        // 6. Tính giờ kết thúc (EndTime)
        const durationTotal = Number(movie.duration) + Number(room.BufferMinutes || 15); 
        const endDateObj = new Date(startDateObj.getTime()); // Copy từ giờ bắt đầu
        endDateObj.setMinutes(endDateObj.getMinutes() + durationTotal); 
        
        const formattedEndTime = `${endDateObj.getFullYear()}-${pad(endDateObj.getMonth() + 1)}-${pad(endDateObj.getDate())} ${pad(endDateObj.getHours())}:${pad(endDateObj.getMinutes())}:00`;

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
        // Lấy UserID của đơn hàng này trước để biết đường gửi thông báo
        const [[bookingInfo]] = await db.promise().query('SELECT UserID FROM bookings WHERE BookingID = ?', [bookingId]);
        const userId = bookingInfo ? bookingInfo.UserID : null;

        if (action === 'approve') {
            await db.promise().query(`UPDATE bookings SET Status = 'Refunded' WHERE BookingID = ?`, [bookingId]);
            await db.promise().query(`UPDATE refunds SET Status = 'Approved', RefundStatus = 'success', ApprovedAt = NOW() WHERE BookingID = ?`, [bookingId]);
            await db.promise().query(`UPDATE bookingseats SET Status = 'Cancelled' WHERE BookingID = ?`, [bookingId]);
            
            // 🚀 THÔNG BÁO HOÀN VÉ THÀNH CÔNG
            if (userId) {
                await db.promise().query(`INSERT INTO notifications (UserID, Title, Type, Content, IsRead, CreatedAt) VALUES (?, '💸 Hoàn vé thành công', 'REFUND', ?, 0, NOW())`, 
                [userId, `Yêu cầu hoàn tiền cho đơn hàng #${bookingId} đã được duyệt. Tiền sẽ về tài khoản trong 24h.`]);
            }
            res.json({ success: true, message: "Đã DUYỆT hoàn tiền và giải phóng ghế!" });

        } else if (action === 'reject') {
            await db.promise().query(`UPDATE bookings SET Status = 'Paid' WHERE BookingID = ?`, [bookingId]);
            await db.promise().query(`UPDATE refunds SET Status = 'Rejected', RefundStatus = 'failed', ApprovedAt = NOW() WHERE BookingID = ?`, [bookingId]);
            
            // 🚀 THÔNG BÁO TỪ CHỐI HOÀN VÉ
            if (userId) {
                await db.promise().query(`INSERT INTO notifications (UserID, Title, Type, Content, IsRead, CreatedAt) VALUES (?, '❌ Hoàn vé thất bại', 'REFUND', ?, 0, NOW())`, 
                [userId, `Yêu cầu hoàn vé #${bookingId} bị từ chối do không thỏa mãn điều kiện quy định.`]);
            }
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

        // 🚀 BẮN THÔNG BÁO CHO TOÀN BỘ KHÁCH HÀNG (MÓN MỚI)
        const broadcastFoodSql = `
            INSERT INTO notifications (UserID, Title, Type, Content, IsRead, CreatedAt)
            SELECT UserID, '🍿 Món mới cực cuốn', 'FOOD', ?, 0, NOW()
            FROM users WHERE IsLocked = 0
        `;
        await db.promise().query(broadcastFoodSql, [`Hệ thống vừa cập nhật món "${Name}" mới. Nhanh tay đặt trước qua App để nhận ưu đãi!`]);
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
        // 🚀 BẮN THÔNG BÁO CHO TOÀN BỘ KHÁCH HÀNG (VOUCHER)
        const broadcastVoucherSql = `
            INSERT INTO notifications (UserID, Title, Type, Content, IsRead, CreatedAt)
            SELECT UserID, '🎁 Tặng bạn mã giảm giá', 'VOUCHER', ?, 0, NOW()
            FROM users WHERE IsLocked = 0
        `;
        let voucherMsg = `Mã "${Code}" giảm ngay ${DiscountPercent}% đã có trong ví của bạn.`;
        if (Number(MaxDiscountAmount) < 999999) voucherMsg += ` (Tối đa ${MaxDiscountAmount}đ)`;
        
        await db.promise().query(broadcastVoucherSql, [voucherMsg]);
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

       // 3. Thi hành án phạt lên User VÀ GỬI THÔNG BÁO
        if (userId && penaltyType) {
            let notifTitle = '';
            let notifContent = '';
            let notifType = '';

            if (penaltyType === 'MUTE_7') {
                const unlockTime = new Date();
                unlockTime.setDate(unlockTime.getDate() + 7);
                await connection.query('UPDATE users SET isLocked = 1, UnlockTime = ? WHERE UserID = ?', [unlockTime, userId]);
                
                notifTitle = '⛔ Tài khoản bị đình chỉ';
                notifType = 'BANNED';
                notifContent = 'Tài khoản của bạn đã bị khóa 7 ngày do lạm dụng tính năng cộng đồng hoặc vi phạm quy định.';
                
            } else if (penaltyType === 'BAN') {
                const forever = new Date('2099-12-31');
                await connection.query('UPDATE users SET isLocked = 1, UnlockTime = ? WHERE UserID = ?', [forever, userId]);
                
                notifTitle = '💀 Khóa vĩnh viễn';
                notifType = 'BANNED';
                notifContent = 'Tài khoản của bạn đã bị cấm vĩnh viễn do vi phạm nghiêm trọng tiêu chuẩn cộng đồng.';
                
            } else if (penaltyType === 'WARN') {
                notifTitle = '🚨 Cảnh báo vi phạm';
                notifType = 'WARNING';
                notifContent = 'Bài viết/bình luận của bạn đã bị xóa do sử dụng ngôn từ không chuẩn mực. Mong bạn tuân thủ!';
            }

            // 🚀 BẮN THÔNG BÁO CẢNH BÁO CHO USER (NẰM TRONG TRANSACTION)
            if (notifTitle !== '') {
                await connection.query('INSERT INTO notifications (UserID, Title, Type, Content, IsRead, CreatedAt) VALUES (?, ?, ?, ?, 0, NOW())', 
                [userId, notifTitle, notifType, notifContent]);
            }
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

// ==============================================================
// 1. API LẤY CẤU HÌNH HỆ THỐNG (ĐÃ FIX LỖI ÉP KIỂU MẤT SỐ 0)
// ==============================================================
router.get('/settings', async (req, res) => {
    try {
        const [rows] = await db.promise().query('SELECT ConfigKey, ConfigValue FROM systemconfigs');
        
        let configData = {};
        
        rows.forEach(row => {
            let val = row.ConfigValue;
            
            // Chỉ ép kiểu chữ 'true' / 'false' thành Boolean (Cho các nút gạt)
            if (val === 'true') val = true;
            else if (val === 'false') val = false;
            
            // 🚀 BỎ CÁI DÒNG ÉP KIỂU Number() ĐI! 
            // Nếu có các trường CẦN LÀ SỐ (như port, thời gian chờ ghế), thì xử lý bằng tay ở Frontend hoặc chỉ check riêng tên biến đó.
            // Ví dụ:
            if (row.ConfigKey === 'smtpPort' || row.ConfigKey === 'seatHoldMinutes' || row.ConfigKey === 'maxTicketsPerOrder' || row.ConfigKey === 'refundBeforeHours') {
                val = Number(val);
            }
            
            configData[row.ConfigKey] = val;
        });

        res.status(200).json(configData);
    } catch (error) {
        console.error("Lỗi lấy cấu hình:", error);
        res.status(500).json({ error: 'Lỗi server khi lấy cấu hình' });
    }
});

// ==============================================================
// 2. API CẬP NHẬT CẤU HÌNH HỆ THỐNG
// ==============================================================
router.put('/settings', async (req, res) => {
    try {
        const configObject = req.body;
        const keys = Object.keys(configObject);
        
        for (const key of keys) {
            // 🚀 LUÔN LƯU VÀO DB DƯỚI DẠNG CHUỖI STRING (String(val)) ĐỂ KHÔNG BỊ TRÔI MẤT SỐ 0
            const value = String(configObject[key]);
            
            await db.promise().query(`
                INSERT INTO systemconfigs (ConfigKey, ConfigValue) 
                VALUES (?, ?) 
                ON DUPLICATE KEY UPDATE ConfigValue = ?, UpdatedAt = CURRENT_TIMESTAMP
            `, [key, value, value]);
        }

        res.status(200).json({ message: 'Lưu cấu hình hệ thống thành công!' });
    } catch (error) {
        console.error("Lỗi cập nhật cấu hình:", error);
        res.status(500).json({ error: 'Lỗi server khi cập nhật cấu hình' });
    }
});

// 1. LẤY DANH SÁCH GIÁ (Cho Admin Web)
router.get('/ticketprices', (req, res) => {
    const sql = `SELECT t.*, c.name as CinemaName FROM ticketprices t LEFT JOIN cinemas c ON t.CinemaID = c.id`;
    db.query(sql, (err, results) => {
        if(err) return res.status(500).send(err);
        res.json(results);
    });
});

// 2. TẠO GIÁ MỚI
router.post('/ticketprices', (req, res) => {
    let { CinemaID, SeatTypeID, ShowType, DayType, Price } = req.body;
    // Chuyển rạp thành NULL nếu Admin chọn "Tất cả rạp"
    if (!CinemaID || CinemaID === "0" || CinemaID === "") CinemaID = null; 
    
    db.query('INSERT INTO ticketprices (CinemaID, SeatTypeID, ShowType, DayType, Price, IsActive) VALUES (?, ?, ?, ?, ?, 1)', 
    [CinemaID, SeatTypeID, ShowType, DayType, Price], (err, results) => {
        if(err) return res.status(500).send(err);
        res.json({ message: 'Tạo thành công' });
    });
});

// 3. SỬA GIÁ
router.put('/ticketprices/:id', (req, res) => {
    let { CinemaID, SeatTypeID, ShowType, DayType, Price } = req.body;
    if (!CinemaID || CinemaID === "0" || CinemaID === "") CinemaID = null;
    
    db.query('UPDATE ticketprices SET CinemaID=?, SeatTypeID=?, ShowType=?, DayType=?, Price=? WHERE PriceID=?', 
    [CinemaID, SeatTypeID, ShowType, DayType, Price, req.params.id], (err, results) => {
        if(err) return res.status(500).send(err);
        res.json({ message: 'Cập nhật thành công' });
    });
});

// 4. XÓA GIÁ
router.delete('/ticketprices/:id', (req, res) => {
    db.query('DELETE FROM ticketprices WHERE PriceID=?', [req.params.id], (err, results) => {
        if(err) return res.status(500).send(err);
        res.json({ message: 'Xóa thành công' });
    });
});

// =====================================================================
// API: BÁO CÁO DOANH THU (TỔNG HỢP & CHI TIẾT)
// =====================================================================
router.get('/reports/revenue', async (req, res) => {
    const { startDate, endDate } = req.query;

    let filterStr = "";
    let params = [];
    if (startDate && endDate) {
        filterStr = " AND DATE(b.CreatedAt) BETWEEN ? AND ? ";
        params.push(startDate, endDate);
    }

    try {
        // 1. DOANH THU PHIM (Gộp)
        const movieSql = `SELECT m.title as movieName, COUNT(bs.SeatID) as ticketsSold, SUM(bs.Price) as totalRevenue FROM bookingseats bs JOIN bookings b ON bs.BookingID = b.BookingID JOIN showtimes st ON bs.ShowtimeID = st.ShowtimeID JOIN movies m ON st.MovieID = m.id WHERE b.Status = 'Paid' ${filterStr} GROUP BY m.id, m.title ORDER BY totalRevenue DESC`;
        
        // 2. DOANH THU BẮP NƯỚC (Gộp theo món)
        const foodSql = `SELECT f.Name as foodName, SUM(bf.Quantity) as quantitySold, SUM(f.Price * bf.Quantity) as totalRevenue FROM bookingfoods bf JOIN foods f ON bf.FoodID = f.FoodID JOIN bookings b ON bf.BookingID = b.BookingID WHERE b.Status = 'Paid' ${filterStr} GROUP BY f.FoodID, f.Name ORDER BY totalRevenue DESC`;

        // 3. DOANH THU VÉ THEO NGÀY
        const ticketByDaySql = `SELECT DATE_FORMAT(b.CreatedAt, '%d/%m/%Y') as date, COUNT(bs.SeatID) as totalTickets, SUM(bs.Price) as totalRevenue FROM bookingseats bs JOIN bookings b ON bs.BookingID = b.BookingID WHERE b.Status = 'Paid' ${filterStr} GROUP BY DATE(b.CreatedAt) ORDER BY DATE(b.CreatedAt) ASC`;

        // 4. 🚀 MỚI: DOANH THU ĐỒ ĂN KÈM THEO NGÀY
        const foodByDaySql = `SELECT DATE_FORMAT(b.CreatedAt, '%d/%m/%Y') as date, SUM(bf.Quantity) as totalQuantity, SUM(f.Price * bf.Quantity) as totalRevenue FROM bookingfoods bf JOIN foods f ON bf.FoodID = f.FoodID JOIN bookings b ON bf.BookingID = b.BookingID WHERE b.Status = 'Paid' ${filterStr} GROUP BY DATE(b.CreatedAt) ORDER BY DATE(b.CreatedAt) ASC`;

        // 5. 🚀 MỚI: CHI TIẾT TẤT CẢ VÉ ĐÃ BÁN (Để xuất Excel)
        const allTicketsSql = `SELECT b.BookingID as bookingId, DATE_FORMAT(b.CreatedAt, '%d/%m/%Y %H:%i') as time, m.title as movieName, s.SeatNumber as seat, bs.Price as price FROM bookingseats bs JOIN bookings b ON bs.BookingID = b.BookingID JOIN showtimes st ON bs.ShowtimeID = st.ShowtimeID JOIN movies m ON st.MovieID = m.id JOIN seats s ON bs.SeatID = s.SeatID WHERE b.Status = 'Paid' ${filterStr} ORDER BY b.CreatedAt DESC`;

        // 6. 🚀 MỚI: CHI TIẾT TẤT CẢ ĐỒ ĂN ĐÃ BÁN (Để xuất Excel)
        const allFoodsSql = `SELECT b.BookingID as bookingId, DATE_FORMAT(b.CreatedAt, '%d/%m/%Y %H:%i') as time, f.Name as foodName, bf.Quantity as quantity, (f.Price * bf.Quantity) as total FROM bookingfoods bf JOIN foods f ON bf.FoodID = f.FoodID JOIN bookings b ON bf.BookingID = b.BookingID WHERE b.Status = 'Paid' ${filterStr} ORDER BY b.CreatedAt DESC`;

        // Chạy song song tất cả query
        const [movieRes] = await db.promise().query(movieSql, params);
        const [foodRes] = await db.promise().query(foodSql, params);
        const [ticketByDayRes] = await db.promise().query(ticketByDaySql, params);
        const [foodByDayRes] = await db.promise().query(foodByDaySql, params);
        const [allTicketsRes] = await db.promise().query(allTicketsSql, params);
        const [allFoodsRes] = await db.promise().query(allFoodsSql, params);

        res.json({
            movies: movieRes,
            foods: foodRes,
            ticketsByDay: ticketByDayRes,
            foodsByDay: foodByDayRes,
            allTickets: allTicketsRes,
            allFoods: allFoodsRes
        });
    } catch (error) {
        console.error("Lỗi API Báo cáo:", error);
        res.status(500).json({ error: "Lỗi truy xuất báo cáo" });
    }
});
// =====================================================================
// API: QUẢN LÝ THÔNG BÁO (NOTIFICATIONS) CỦA ADMIN
// =====================================================================

// 1. API Lấy danh sách thông báo (Lấy 30 cái mới nhất đẩy lên chuông)
router.get('/notifications', (req, res) => {
    // ✅ FIX 1: CHỈ LẤY THÔNG BÁO CỦA ADMIN (UserID IS NULL)
    const sql = 'SELECT * FROM notifications WHERE UserID IS NULL ORDER BY CreatedAt DESC LIMIT 30';
    db.query(sql, (err, results) => {
        if(err) return res.status(500).send(err);
        res.json(results);
    });
});

// 2. API Đánh dấu 1 thông báo cụ thể là "Đã đọc"
router.put('/notifications/:id/read', (req, res) => {
    // ✅ FIX 2: Khóa bảo mật thêm lớp UserID IS NULL
    const sql = 'UPDATE notifications SET IsRead = 1 WHERE NotificationID = ? AND UserID IS NULL';
    db.query(sql, [req.params.id], (err, results) => {
        if(err) return res.status(500).send(err);
        res.json({ message: 'Đã đánh dấu đọc thông báo này' });
    });
});

// 3. API Đánh dấu đọc TẤT CẢ thông báo (Cho nút "Đọc hết" có biểu tượng 2 dấu tick)
router.put('/notifications/read-all', (req, res) => {
    // ✅ FIX 3: NGĂN CHẶN ADMIN LỠ TAY ĐÁNH DẤU "ĐÃ ĐỌC" LUÔN CẢ THÔNG BÁO CỦA KHÁCH HÀNG
    const sql = 'UPDATE notifications SET IsRead = 1 WHERE IsRead = 0 AND UserID IS NULL';
    db.query(sql, (err, results) => {
        if(err) return res.status(500).send(err);
        res.json({ message: 'Đã dọn dẹp sạch sẽ chuông thông báo' });
    });
});

module.exports = router;