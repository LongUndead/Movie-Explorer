const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const qs = require('qs');
const moment = require('moment');
const axios = require('axios');
const db = require('./db');

// ==========================================
// 1. API TẠO LINK THANH TOÁN VNPAY
// ==========================================
router.post('/api/vnpay/create_url', (req, res) => {
    // ⚠️ ĐÂY LÀ THÔNG TIN BẠN LẤY TỪ TRANG QUẢN TRỊ VNPAY SANDBOX
    const tmnCode = 'HRZXJC9Y'; // Mã website
    const secretKey = 'UV7Y1OZ8XELRR21CDGM295NB0NDICOBX'; // Chuỗi bí mật
    let vnpUrl = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
    const returnUrl = 'https://google.com'; // Nơi trình duyệt trả về sau khi thanh toán

    const date = new Date();
    const createDate = moment(date).format('YYYYMMDDHHmmss');
    
    // Lấy thông tin từ Flutter gửi lên
    const amount = req.body.amount; 
    const orderId = req.body.orderId || moment(date).format('DDHHmmss');
    const orderInfo = req.body.orderInfo || 'Thanh toan ve xem phim';
    const ipAddr = req.headers['x-forwarded-for'] || req.connection.remoteAddress || req.socket.remoteAddress || '127.0.0.1';

    let vnp_Params = {};
    vnp_Params['vnp_Version'] = '2.1.0';
    vnp_Params['vnp_Command'] = 'pay';
    vnp_Params['vnp_TmnCode'] = tmnCode;
    vnp_Params['vnp_Locale'] = 'vn';
    vnp_Params['vnp_CurrCode'] = 'VND';
    vnp_Params['vnp_TxnRef'] = orderId;
    vnp_Params['vnp_OrderInfo'] = orderInfo;
    vnp_Params['vnp_OrderType'] = 'billpayment';
    vnp_Params['vnp_Amount'] = amount * 100; // VNPAY yêu cầu nhân 100 (VD: 100000 vnđ -> 10000000)
    vnp_Params['vnp_ReturnUrl'] = returnUrl;
    vnp_Params['vnp_IpAddr'] = ipAddr;
    vnp_Params['vnp_CreateDate'] = createDate;

    // 1. Sắp xếp các key theo thứ tự Alphabet
    vnp_Params = sortObject(vnp_Params);

    // 2. Ép kiểu thành chuỗi Query String
    let signData = qs.stringify(vnp_Params, { encode: false });

    // 3. Băm chuỗi bằng thuật toán HMAC SHA512 với Secret Key
    let hmac = crypto.createHmac("sha512", secretKey);
    let signed = hmac.update(Buffer.from(signData, 'utf-8')).digest("hex"); 

    // 4. Gắn chữ ký bảo mật vào Params và tạo URL cuối cùng
    vnp_Params['vnp_SecureHash'] = signed;
    vnpUrl += '?' + qs.stringify(vnp_Params, { encode: false });

    // Trả cái URL xịn xò này về cho Flutter mở lên
    res.status(200).json({ paymentUrl: vnpUrl });
});


// ==========================================
// 2. API TẠO LINK THANH TOÁN MOMO
// ==========================================
router.post('/api/momo/create_url', async (req, res) => {
    // =========================================================
    // ⚠️ BỘ KEY TEST CHUẨN 100% CỦA MOMO DEVELOPER
    // =========================================================
    const partnerCode = "MOMOBKUN20180529";
    const accessKey = "klm05TvNBzhg7h7j";
    const secretKey = "at67qH6mk8w5Y1nAyMoYKMWACiEi2bsa";
    
    const endpoint = "https://test-payment.momo.vn/v2/gateway/api/create";
    const redirectUrl = "http://192.168.1.2:3000/api/momo/return";
    const ipnUrl = "http://192.168.1.2:3000/api/momo/ipn"; 

    const amountNum = Number(req.body.amount); 
    const amountStr = String(amountNum);       
    
    // Gắn thêm tiền tố để ID là Độc nhất (Không đụng hàng với ai)
    const realBookingId = String(req.body.orderId); 
    const orderIdStr = "MOMO_" + realBookingId + "_" + new Date().getTime(); 
    const requestId = orderIdStr;
    
    const orderInfo = "Thanh toan don hang Cinema"; 
    
    // =========================================================
    // ✅ ĐÃ SỬA CHỖ NÀY: Chuyển sang thanh toán bằng THẺ ATM
    // =========================================================
    const requestType = "payWithATM"; 
    
    const extraData = ""; 

    // 1. Tạo chữ ký (Tuyệt đối không đổi thứ tự)
    const rawSignature = "accessKey=" + accessKey + "&amount=" + amountStr + "&extraData=" + extraData + 
                         "&ipnUrl=" + ipnUrl + "&orderId=" + orderIdStr + "&orderInfo=" + orderInfo + 
                         "&partnerCode=" + partnerCode + "&redirectUrl=" + redirectUrl + 
                         "&requestId=" + requestId + "&requestType=" + requestType;

    const signature = crypto.createHmac('sha256', secretKey).update(rawSignature).digest('hex');

    // 2. Gửi JSON
    const requestBody = JSON.stringify({
        partnerCode: partnerCode,
        accessKey: accessKey,
        requestId: requestId,
        amount: amountNum,   
        orderId: orderIdStr, 
        orderInfo: orderInfo,
        redirectUrl: redirectUrl,
        ipnUrl: ipnUrl,
        extraData: extraData,
        requestType: requestType,
        signature: signature,
        lang: 'vi'
    });

    try {
        const result = await axios.post(endpoint, requestBody, {
            headers: { 'Content-Type': 'application/json' }
        });
        // In ra màn hình Node.js để ăn mừng
        console.log("🔥 MOMO SUCCESS: Đã tạo link thành công!");
        res.status(200).json({ paymentUrl: result.data.payUrl });
    } catch (error) {
        console.error("LỖI MOMO TRẢ VỀ:", error.response ? error.response.data : error.message);
        res.status(500).json({ error: "Không thể tạo link MoMo" });
    }
});
// API: Cập nhật trạng thái sau khi thanh toán thành công
router.post('/api/bookings/confirm_payment', async (req, res) => {
    const { bookingId, amount, transactionNo, bankCode, orderInfo } = req.body;

    try {
        // 1. Cập nhật bảng `bookings` -> Đã thanh toán
        await db.query(`UPDATE bookings SET Status = 'Paid' WHERE BookingID = ?`, [bookingId]);

        // 2. Cập nhật bảng `bookingseats` thành 'Occupied' cho khớp với Flutter
        await db.query(`UPDATE bookingseats SET Status = 'Occupied' WHERE BookingID = ?`, [bookingId]);

        // ==========================================
        // 3. ✅ QUAN TRỌNG: Dọn sạch seatholds (Dùng JOIN tự động tìm và xóa)
        // ==========================================
        await db.query(`
            DELETE sh FROM seatholds sh
            JOIN bookingseats bs ON sh.SeatID = bs.SeatID AND sh.ShowtimeID = bs.ShowtimeID
            WHERE bs.BookingID = ?
        `, [bookingId]);

        // 4. Lưu biên lai vào bảng `payments`
        const paymentQuery = `
            INSERT INTO payments 
            (BookingID, Method, Amount, TransactionNo, BankCode, ResponseCode, OrderInfo, Provider, PaymentStatus, Status, PaidAt)
            VALUES (?, 'VNPAY', ?, ?, ?, '00', ?, 'VNPAY', 'Success', 'Active', NOW())
        `;
        await db.query(paymentQuery, [bookingId, amount, transactionNo, bankCode, orderInfo]);

        res.status(200).json({ message: "Chốt vé thành công! Ghế đã được khóa." });
    } catch (error) {
        console.error("Lỗi khi update DB:", error);
        res.status(500).json({ error: "Lỗi hệ thống" });
    }
});
// API: Hủy đơn hàng và nhả ghế khi thanh toán thất bại / hủy thanh toán
router.post('/api/bookings/cancel_payment', async (req, res) => {
    const { bookingId } = req.body;

    if (!bookingId) {
        return res.status(400).json({ error: "Thiếu mã BookingID" });
    }

    try {
        // 1. Cập nhật bảng `bookings` -> Trạng thái Đã Hủy
        await db.query(`UPDATE bookings SET Status = 'Cancelled' WHERE BookingID = ?`, [bookingId]);

        // 2. XÓA CÁC GHẾ ĐANG GIỮ CHỖ TRONG BẢNG `bookingseats`
        // Việc xóa dòng này giúp ghế tự động trở lại màu trắng (trống) cho người khác mua.
        // (Nếu Database của bạn không cho phép xóa mà bắt lưu lịch sử, hãy đổi thành: 
        // UPDATE bookingseats SET Status = 'Cancelled' WHERE BookingID = ?)
        await db.query(`DELETE FROM bookingseats WHERE BookingID = ?`, [bookingId]);

        // 3. (Tùy chọn) Xóa bắp nước đã đặt trong `bookingfoods` nếu có
        // await db.query(`DELETE FROM bookingfoods WHERE BookingID = ?`, [bookingId]);

        res.status(200).json({ message: "Hủy vé thành công, đã nhả ghế!" });
    } catch (error) {
        console.error("Lỗi khi hủy đơn:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi hủy đơn" });
    }
});
// 1. Hàm helper tạo mã ngẫu nhiên (Giữ nguyên của bạn)
function generateRandomString() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    let chars = [];
    for (let i = 0; i < 5; i++) chars.push(letters.charAt(Math.floor(Math.random() * letters.length)));
    for (let i = 0; i < 2; i++) chars.push(numbers.charAt(Math.floor(Math.random() * numbers.length)));
    chars.sort(() => Math.random() - 0.5);
    return chars.join(''); 
}

// 2. ✅ HÀM MỚI: Kiểm tra Database chống trùng lặp tuyệt đối
async function generateUniqueBookingCode(db) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    let isUnique = false;
    let newCode = '';

    while (!isUnique) {
        let chars = [];
        for (let i = 0; i < 5; i++) chars.push(letters.charAt(Math.floor(Math.random() * letters.length)));
        for (let i = 0; i < 2; i++) chars.push(numbers.charAt(Math.floor(Math.random() * numbers.length)));
        chars.sort(() => Math.random() - 0.5);
        newCode = chars.join('');

        // Kiểm tra xem mã này đã tồn tại ở ghế hay thức ăn chưa
        const [seats] = await db.query(`SELECT QRCode FROM bookingseats WHERE QRCode = ? LIMIT 1`, [newCode]);
        const [foods] = await db.query(`SELECT QRCode FROM bookingfoods WHERE QRCode = ? LIMIT 1`, [newCode]);

        if (seats.length === 0 && foods.length === 0) {
            isUnique = true; // Tuyệt đối chưa ai xài thì mới lấy
        }
    }
    return newCode;
}
// ==========================================
// API TẠO ĐƠN HÀNG NHÁP TRƯỚC KHI THANH TOÁN
// ==========================================
router.post('/api/bookings/create_pending', async (req, res) => {
    // ✅ 1. SỬA: Nhận thêm biến cinemaId từ Flutter
    const { userId, showtimeId, cinemaId, totalAmount, seats, foods } = req.body;

    try {
        // ✅ 2. SỬA: Xử lý showtimeId an toàn. Nếu = 0 hoặc undefined (chỉ mua bắp) thì gán thành null
        const validShowtimeId = (showtimeId && showtimeId !== 0) ? showtimeId : null;

        // ✅ 3. SỬA: LƯU BẢNG bookings (Thêm cột CinemaID vào để lưu rạp)
        const queryBooking = `INSERT INTO bookings (UserID, ShowtimeID, CinemaID, TotalAmount, Status) VALUES (?, ?, ?, ?, 'Pending')`;
        const [result] = await db.query(queryBooking, [userId, validShowtimeId, cinemaId, totalAmount]);
        
        const bookingId = result.insertId; 

        // =======================================================
        // ✅ TẠO 1 MÃ DUY NHẤT NGAY TẠI ĐÂY (TRƯỚC KHI LƯU GHẾ HAY BẮP)
        // =======================================================
        const finalBookingCode = await generateUniqueBookingCode(db);

        // 3. LƯU BẢNG bookingseats
        if (seats && seats.length > 0) {
            for (let seat of seats) {
                let bookingSeatId = Math.floor(10000000 + Math.random() * 90000000).toString();

                await db.query(
                    `INSERT INTO bookingseats (BookingSeatID, BookingID, ShowtimeID, SeatID, Price, QRCode, Status) VALUES (?, ?, ?, ?, ?, ?, 'Pending')`, 
                    [bookingSeatId, bookingId, validShowtimeId, seat.id, seat.price, finalBookingCode] 
                );
            }

            // Dọn rác seatholds ngay khi vừa tạo vé Nháp
            const seatIds = seats.map(s => s.id);
            const placeholders = seatIds.map(() => '?').join(',');
            await db.query(
                `DELETE FROM seatholds WHERE ShowtimeID = ? AND SeatID IN (${placeholders})`, 
                [validShowtimeId, ...seatIds]
            );
        }

        // 4. LƯU BẢNG bookingfoods
        if (foods && foods.length > 0) {
            for (let food of foods) {
                let bookingFoodId = Math.floor(10000000 + Math.random() * 90000000).toString();

                await db.query(
                    `INSERT INTO bookingfoods (BookingFoodID, BookingID, FoodID, Quantity, Price, QRCode) VALUES (?, ?, ?, ?, ?, ?)`, 
                    [bookingFoodId, bookingId, food.id, food.quantity, food.price, finalBookingCode] 
                );
            }
        }

        // 5. Trả ID về cho Flutter để mang đi thanh toán VNPAY
        res.status(200).json({ bookingId: bookingId.toString() });
    } catch (error) {
        console.error("❌ LỖI KHI TẠO ĐƠN NHÁP:", error); 
        res.status(500).json({ error: "Lỗi lưu Database" });
    }
});

// API Lấy danh sách ghế của 1 suất chiếu
router.get('/api/seats/:showtimeId', async (req, res) => {
    const showtimeId = req.params.showtimeId;
    try {
        // ✅ Dùng LEFT JOIN để lấy trạng thái 'Occupied' từ bảng bookingseats
        const query = `
            SELECT s.*, 
                   IFNULL(bs.Status, 'Available') AS Status
            FROM seats s
            JOIN showtimes st ON s.RoomID = st.RoomID
            LEFT JOIN bookingseats bs ON s.SeatID = bs.SeatID AND bs.ShowtimeID = ?
            WHERE st.ShowtimeID = ?
        `;
        const [seats] = await db.query(query, [showtimeId, showtimeId]);
        res.status(200).json(seats);
    } catch (error) {
        console.error("Lỗi lấy ghế:", error);
        res.status(500).json({ error: "Lỗi hệ thống" });
    }
});

// ==========================================
// HÀM HỖ TRỢ: Sắp xếp Object (BẮT BUỘC CHO VNPAY)
// ==========================================
function sortObject(obj) {
    let sorted = {};
    let str = [];
    let key;
    for (key in obj) {
        if (obj.hasOwnProperty(key)) {
            str.push(encodeURIComponent(key));
        }
    }
    str.sort();
    for (key = 0; key < str.length; key++) {
        sorted[str[key]] = encodeURIComponent(obj[str[key]]).replace(/%20/g, "+");
    }
    return sorted;
}

module.exports = router;