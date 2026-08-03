const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const qs = require('qs');
const moment = require('moment');
const axios = require('axios');
const nodemailer = require('nodemailer');
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
    const NGROK_URL = "https://sneeze-dust-linguist.ngrok-free.dev";
    const redirectUrl = "https://google.com/momo_return";
    
    // Vẫn dùng httpbin để lừa máy chủ MoMo báo IPN thành công
    const ipnUrl = NGROK_URL + "/api/momo/ipn";

    const amountNum = Number(req.body.amount); 
    const amountStr = String(amountNum);       
    
    // Gắn thêm tiền tố để ID là Độc nhất (Không đụng hàng với ai)
    const realBookingId = String(req.body.orderId); 
    const orderIdStr = "MOMO_" + realBookingId + "_" + new Date().getTime(); 
    const requestId = orderIdStr;
    
    
    const orderInfo = "Thanh Toán Đơn Hàng CinemaTickets."; 
    
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
        console.log(result.data);
        // In ra màn hình Node.js để ăn mừng
        console.log("🔥 MOMO SUCCESS: Đã tạo link thành công!");
        res.status(200).json({ paymentUrl: result.data.payUrl });
    } catch (error) {
        console.error("LỖI MOMO TRẢ VỀ:", error.response ? error.response.data : error.message);
        res.status(500).json({ error: "Không thể tạo link MoMo" });
    }
});

// ==========================================
// 3. API TẠO LINK THANH TOÁN ZALOPAY
// ==========================================
router.post('/api/zalopay/create_url', async (req, res) => {
    // ⚠️ Bộ Key Test chuẩn Sandbox của ZaloPay Developer
    const config = {
        app_id: "2553",
        key1: "PcY4iZIKFCIdgZvA6ueMcMHHUbRLYjPL",
        key2: "kLtgPl8YESYV3vchL270Zp3B2VNzql2G",
        endpoint: "https://sb-openapi.zalopay.vn/v2/create"
    };

    const amount = Number(req.body.amount);
    const orderId = String(req.body.orderId); // Bằng với bookingId

    // Format mã giao dịch: yyMMdd_xxxxx
    const date = new Date();
    const y = String(date.getFullYear()).slice(2);
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    const app_trans_id = `${y}${m}${d}_${orderId}_${Date.now()}`;

    // 🚀 BÍ QUYẾT: Dùng link HTTPS giả định để Webview Android không chặn
    const embed_data = JSON.stringify({
        redirecturl: "https://google.com/zalopay_return" 
    });

    const item = JSON.stringify([{ name: "Ve xem phim", quantity: 1, price: amount }]);
    const description = "Thanh toan don hang CinemaTickets";
    const app_user = "customer";

    // Tạo chuỗi MAC
    const macData = config.app_id + "|" + app_trans_id + "|" + app_user + "|" + amount + "|" + Date.now() + "|" + embed_data + "|" + item;
    const mac = crypto.createHmac("sha256", config.key1).update(macData).digest("hex");

    const body = {
        app_id: config.app_id,
        app_user: app_user,
        app_trans_id: app_trans_id,
        app_time: Date.now(),
        amount: amount,
        item: item,
        embed_data: embed_data,
        description: description,
        bank_code: "",
        mac: mac
    };

    try {
        const result = await axios.post(config.endpoint, body, {
            headers: { "Content-Type": "application/x-www-form-urlencoded" }
        });

        if (result.data.return_code === 1) {
            console.log("🔥 ZALOPAY SUCCESS: Đã tạo link thành công!");
            res.json({ paymentUrl: result.data.order_url, app_trans_id: app_trans_id });
        } else {
            console.error("❌ ZALOPAY TỪ CHỐI TẠO LINK:", result.data.return_message);
            // =========================================================================
            // 🧹 BỌC LỖI NODE.JS: Tự động gọi API hủy đơn của chính mình để nhả ghế
            // =========================================================================
            await axios.post('http://localhost:3000/api/bookings/cancel_payment', { bookingId: orderId })
                       .catch(e => console.log("Lỗi khi auto-rollback", e.message));

            res.status(400).json({ message: result.data.return_message });
        }
    } catch (error) {
        console.error("❌ LỖI MẠNG ZALOPAY:", error.message);
        // =========================================================================
        // 🧹 BỌC LỖI NODE.JS: Lỗi mạng sập cũng tự dọn ghế Pending
        // =========================================================================
        await axios.post('http://localhost:3000/api/bookings/cancel_payment', { bookingId: orderId })
                   .catch(e => console.log("Lỗi khi auto-rollback", e.message));

        res.status(500).json({ error: "Không thể tạo link ZaloPay" });
    }
});

router.get('/api/momo/return', (req, res) => {
    console.log("===== MOMO RETURN =====");
    console.log(req.query);

    res.send("MoMo Return OK");
});
router.post('/api/momo/ipn', async (req, res) => {
    console.log("===== MOMO IPN =====");
    console.log(req.body);

    res.status(200).json({ message: "OK" });
});
// API: Cập nhật trạng thái sau khi thanh toán thành công
router.post('/api/bookings/confirm_payment', async (req, res) => {
    // ✅ ĐÃ SỬA: Lấy thêm provider và method từ Flutter gửi lên
    const { bookingId, amount, transactionNo, bankCode, orderInfo, provider, method } = req.body;

    // Đề phòng trường hợp Flutter bản cũ chưa gửi provider/method, mình fallback về bankCode
    const finalProvider = provider || bankCode;
    const finalMethod = method || bankCode;

    try {

        // ========================================================
        // 🚀 KỸ THUẬT ATOMIC UPDATE: CHỐT CHẶN RACE CONDITION TUYỆT ĐỐI
        // Chỉ Update thành 'Paid' nếu hiện tại nó ĐANG LÀ 'Pending'
        // ========================================================
        const [updateResult] = await db.promise().query(
            `UPDATE bookings SET Status = 'Paid' WHERE BookingID = ? AND Status = 'Pending'`, 
            [bookingId]
        );

        // Nếu affectedRows = 0 nghĩa là Đơn hàng ĐÃ ĐƯỢC CHỐT THÀNH PAID TỪ TRƯỚC RỒI!
        if (updateResult.affectedRows === 0) {
            console.log(`[CẢNH BÁO] Luồng thừa thứ 2 chạy vào Đơn #${bookingId}. Đã khóa mỏ! 🔒`);
            return res.status(200).json({ message: "Đơn hàng đã được xử lý xong từ trước. Bỏ qua luồng phụ." });
        }

        // 2. Cập nhật bảng `bookingseats` thành 'Occupied' cho khớp với Flutter
        await db.promise().query(`UPDATE bookingseats SET Status = 'Occupied' WHERE BookingID = ?`, [bookingId]);

        // ==========================================
        // 3. ✅ QUAN TRỌNG: Dọn sạch seatholds (Dùng JOIN tự động tìm và xóa)
        // ==========================================
        await db.promise().query(`
            DELETE sh FROM seatholds sh
            JOIN bookingseats bs ON sh.SeatID = bs.SeatID AND sh.ShowtimeID = bs.ShowtimeID
            WHERE bs.BookingID = ?
        `, [bookingId]);

        // ==========================================
        // 4. ✅ ĐÃ FIX LỖI: Lưu biên lai vào bảng `payments` động theo Cổng thanh toán
        // ==========================================
        const paymentQuery = `
            INSERT INTO payments 
            (BookingID, Method, Amount, TransactionNo, BankCode, ResponseCode, OrderInfo, Provider, PaymentStatus, Status, PaidAt)
            VALUES (?, ?, ?, ?, ?, '00', ?, ?, 'Success', 'Active', NOW())
        `;
        // Thay chữ 'VNPAY' bằng 2 dấu ? và truyền finalMethod, finalProvider vào đây:
        await db.promise().query(paymentQuery, [
            bookingId, 
            finalMethod, 
            amount, 
            transactionNo, 
            bankCode, 
            orderInfo, 
            finalProvider
        ]);

       // =========================================================
        // 5. 🚀 TRÍCH XUẤT DỮ LIỆU VÀ TỰ ĐỘNG GỬI EMAIL CHO KHÁCH
        // =========================================================
        try {
            // ✅ ĐÃ NÂNG CẤP SQL: Lấy thêm Tên rạp, Phòng chiếu, Ghế, Bắp nước, Số tiền
            const queryMailData = `
                SELECT 
                    u.Email, u.Username,
                    m.title AS MovieName,
                    st.StartTime, st.movie_format AS MovieFormat,
                    c.Name AS CinemaName, r.Name AS RoomName,
                    b.TotalAmount,
                    (SELECT Method FROM payments WHERE BookingID = b.BookingID LIMIT 1) AS PaymentMethod,
                    (SELECT QRCode FROM bookingseats WHERE BookingID = b.BookingID LIMIT 1) AS SeatQRCode,
                    (SELECT QRCode FROM bookingfoods WHERE BookingID = b.BookingID LIMIT 1) AS FoodQRCode,
                    (SELECT GROUP_CONCAT(s2.SeatNumber SEPARATOR ', ') FROM bookingseats bs2 JOIN seats s2 ON bs2.SeatID = s2.SeatID WHERE bs2.BookingID = b.BookingID) AS Seats,
                    (SELECT GROUP_CONCAT(CONCAT(f.Name, ' x', bf.Quantity) SEPARATOR ', ') FROM bookingfoods bf JOIN foods f ON bf.FoodID = f.FoodID WHERE bf.BookingID = b.BookingID) AS Foods
                FROM bookings b
                JOIN users u ON b.UserID = u.UserID
                LEFT JOIN showtimes st ON b.ShowtimeID = st.ShowtimeID
                LEFT JOIN movies m ON st.MovieID = m.id
                LEFT JOIN rooms r ON st.RoomID = r.RoomID
                LEFT JOIN cinemas c ON r.CinemaID = c.id
                WHERE b.BookingID = ?
            `;
            
            const [mailDataRows] = await db.promise().query(queryMailData, [bookingId]);

            if (mailDataRows.length > 0) {
                const mailInfo = mailDataRows[0];
                const userEmail = mailInfo.Email;
                
                const ticketCode = mailInfo.SeatQRCode || mailInfo.FoodQRCode || "N/A";
                let movieName = mailInfo.MovieName || "Đơn Thức Ăn & Đồ Uống";
                let showTime = "Nhận trong ngày";

                // Format thời gian
                if (mailInfo.StartTime) {
                    const dateObj = new Date(mailInfo.StartTime);
                    const hours = String(dateObj.getHours()).padStart(2, '0');
                    const minutes = String(dateObj.getMinutes()).padStart(2, '0');
                    const dd = String(dateObj.getDate()).padStart(2, '0');
                    const mm = String(dateObj.getMonth() + 1).padStart(2, '0');
                    const yyyy = dateObj.getFullYear();
                    showTime = `${hours}:${minutes} - ${dd}/${mm}/${yyyy}`;
                }

                if (userEmail && userEmail.includes('@')) {
                    console.log(`⏳ Đang tiến hành gửi mail vé chuẩn xịn cho: ${userEmail}`);
                    
                    // Gói toàn bộ dữ liệu thành 1 Object để truyền đi
                    const mailPayload = {
                        email: userEmail,
                        customerName: mailInfo.Username || 'Quý khách',
                        cinemaName: mailInfo.CinemaName || 'CinemaTickets',
                        movieName: movieName,
                        movieFormat: mailInfo.MovieFormat || '2D Standard',
                        roomName: mailInfo.RoomName || '',
                        showTime: showTime,
                        seats: mailInfo.Seats || 'Không có',
                        foods: mailInfo.Foods || 'Không có',
                        totalAmount: mailInfo.TotalAmount || 0,
                        paymentMethod: mailInfo.PaymentMethod || 'Thanh toán trực tuyến',
                        ticketCode: ticketCode
                    };

                    // 🚀 GỌI HÀM GỬI EMAIL CHẠY NGẦM
                    sendTicketEmail(mailPayload);
                }
            }
        } catch (mailErr) {
            console.error("❌ Lỗi truy xuất data gửi mail:", mailErr);
        }

        // ========================================================
        // 🚀 TỰ ĐỘNG TÌM ID CỦA KHÁCH HÀNG TỪ MÃ ĐƠN HÀNG
        // ========================================================
        const [bookingData] = await db.promise().query('SELECT UserID FROM bookings WHERE BookingID = ?', [bookingId]);
        const userId = bookingData.length > 0 ? bookingData[0].UserID : null;

        if (userId) {
            // Dành cho Khách Hàng (Hiện trên App Mobile)
            // ✅ ĐÃ FIX LỖI: 5 Cột (UserID, Title, Type, Content, ActionURL) -> Đi với 5 dấu ?
            const notifAppSql = `INSERT INTO notifications (UserID, Title, Type, Content, ActionURL, IsRead, CreatedAt) VALUES (?, ?, ?, ?, ?, 0, NOW())`;
            await db.promise().query(notifAppSql, [
                userId, 
                "🎫 Đặt vé thành công!", 
                "BOOKING", 
                `Bạn đã thanh toán thành công đơn hàng #${bookingId}. Chúc bạn xem phim vui vẻ!`, 
                "/tickets"
            ]);
        }

        // ========================================================
        // TẠO THÔNG BÁO RIÊNG CHO ADMIN (Không truyền UserID)
        // ========================================================
        const notifContent = `Khách hàng vừa thanh toán đơn hàng thành công. Mã ĐH: #${bookingId}`; 
        
        // ✅ ĐÃ FIX LỖI: 4 Cột (Title, Type, Content, ActionURL) -> Đi với 4 dấu ?
        const notifSql = `INSERT INTO notifications (Title, Type, Content, ActionURL, IsRead, CreatedAt) VALUES (?, ?, ?, ?, 0, NOW())`;

        db.query(notifSql, ["🎟️ Đơn hàng mới!", "BOOKING", notifContent, "/orders"], (err, results) => {
            if(err) console.log("Lỗi tạo thông báo Admin:", err);
        });

        // Trả kết quả về cho Flutter
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
        await db.promise().query(`UPDATE bookings SET Status = 'Cancelled' WHERE BookingID = ?`, [bookingId]);

        // 2. XÓA CÁC GHẾ ĐANG GIỮ CHỖ TRONG BẢNG `bookingseats`
        // Việc xóa dòng này giúp ghế tự động trở lại màu trắng (trống) cho người khác mua.
        // (Nếu Database của bạn không cho phép xóa mà bắt lưu lịch sử, hãy đổi thành: 
        // UPDATE bookingseats SET Status = 'Cancelled' WHERE BookingID = ?)
        await db.promise().query(`DELETE FROM bookingseats WHERE BookingID = ?`, [bookingId]);

        // 3. (Tùy chọn) Xóa bắp nước đã đặt trong `bookingfoods` nếu có
        // await db.promise().query(`DELETE FROM bookingfoods WHERE BookingID = ?`, [bookingId]);

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
        const [seats] = await db.promise().query(`SELECT QRCode FROM bookingseats WHERE QRCode = ? LIMIT 1`, [newCode]);
        const [foods] = await db.promise().query(`SELECT QRCode FROM bookingfoods WHERE QRCode = ? LIMIT 1`, [newCode]);

        if (seats.length === 0 && foods.length === 0) {
            isUnique = true; // Tuyệt đối chưa ai xài thì mới lấy
        }
    }
    return newCode;
}
// ==========================================
// API TẠO ĐƠN HÀNG NHÁP TRƯỚC KHI THANH TOÁN (ĐÃ BẢO MẬT VOUCHER)
// ==========================================
router.post('/api/bookings/create_pending', async (req, res) => {
    // ✅ 1. SỬA: Nhận thêm `voucherId` từ phía Flutter gửi lên
    const { userId, showtimeId, cinemaId, seats, foods, voucherId } = req.body;
    console.log("👉 Dữ liệu mảng seats từ Flutter gửi lên:", seats);

    try {
        // ✅ 2. SỬA: Xử lý showtimeId an toàn. Nếu = 0 hoặc undefined (chỉ mua bắp) thì gán thành null
        const validShowtimeId = (showtimeId && showtimeId !== 0) ? showtimeId : null;

        // =======================================================
        // 🛡️ BƯỚC 3.1: TỰ TÍNH TỔNG TIỀN GỐC TỪ SEATS VÀ FOODS (CHỐNG HACK GIÁ)
        // =======================================================
        let rawTotalAmount = 0;
        
        if (seats && seats.length > 0) {
            for (let seat of seats) {
                rawTotalAmount += Number(seat.price) || 0;
            }
        }

        if (foods && foods.length > 0) {
            for (let food of foods) {
                rawTotalAmount += (Number(food.price) * Number(food.quantity)) || 0;
            }
        }

        // =======================================================
        // 🛡️ BƯỚC 3.2: KIỂM TRA VÀ TÍNH TOÁN VOUCHER TRÊN SERVER
        // =======================================================
        let discountAmount = 0;
        let finalVoucherId = null;

        if (voucherId) {
            // Query trực tiếp từ bảng vouchers của ông (dựa theo cấu trúc hình ảnh)
            const [voucherRows] = await db.promise().query(
                `SELECT * FROM vouchers WHERE VoucherID = ? AND (Quantity > 0 OR Quantity IS NULL)`, 
                [voucherId]
            );

            if (voucherRows.length > 0) {
                const v = voucherRows[0];
                const minOrderValue = Number(v.MinOrderValue) || 0;
                const discountPercent = Number(v.DiscountPercent) || 0;
                // Nếu MaxDiscountAmount trong DB là 999999999 thì hiểu là không giới hạn
                const maxDiscountAmount = Number(v.MaxDiscountAmount) || 999999999; 

                // 🛑 Kiểm tra xem đơn hàng có đạt giá trị tối thiểu không?
                if (rawTotalAmount >= minOrderValue) {
                    // Tính phần trăm giảm giá
                    let calculatedDiscount = Math.round((rawTotalAmount * discountPercent) / 100);
                    
                    // Luật 1: Cắt ngọn (Không vượt quá mức giảm tối đa của mã)
                    calculatedDiscount = Math.min(calculatedDiscount, maxDiscountAmount);
                    
                    // Luật 2: Chống âm tiền (Không giảm quá tổng tiền đơn hàng)
                    calculatedDiscount = Math.min(calculatedDiscount, rawTotalAmount);

                    discountAmount = calculatedDiscount;
                    finalVoucherId = v.VoucherID;
                }
            }
        }

        // SỐ TIỀN THỰC TẾ CUỐI CÙNG SAU KHI TRỪ VOUCHER
        const finalAmount = Math.max(0, rawTotalAmount - discountAmount);

        // =======================================================
        // ✅ 3.3: LƯU BẢNG bookings (Dùng `finalAmount` đã được bảo mật)
        // =======================================================
        const queryBooking = `INSERT INTO bookings (UserID, ShowtimeID, CinemaID, TotalAmount, Status) VALUES (?, ?, ?, ?, 'Pending')`;
        const [result] = await db.promise().query(queryBooking, [userId, validShowtimeId, cinemaId, finalAmount]);
        
        const bookingId = result.insertId; 

        // =======================================================
        // ✅ TẠO 1 MÃ DUY NHẤT NGAY TẠI ĐÂY (TRƯỚC KHI LƯU GHẾ HAY BẮP)
        // =======================================================
        const finalBookingCode = await generateUniqueBookingCode(db);

        // 3. LƯU BẢNG bookingseats
        if (seats && seats.length > 0) {
            for (let seat of seats) {
                let bookingSeatId = Math.floor(10000000 + Math.random() * 90000000).toString();

                await db.promise().query(
                    `INSERT INTO bookingseats (BookingSeatID, BookingID, ShowtimeID, SeatID, Price, QRCode, Status) VALUES (?, ?, ?, ?, ?, ?, 'Pending')`, 
                    [bookingSeatId, bookingId, validShowtimeId, seat.id, seat.price, finalBookingCode] 
                );
            }

            // Dọn rác seatholds ngay khi vừa tạo vé Nháp
            const seatIds = seats.map(s => s.id);
            const placeholders = seatIds.map(() => '?').join(',');
            await db.promise().query(
                `DELETE FROM seatholds WHERE ShowtimeID = ? AND SeatID IN (${placeholders})`, 
                [validShowtimeId, ...seatIds]
            );
        }

        // 4. LƯU BẢNG bookingfoods
        if (foods && foods.length > 0) {
            for (let food of foods) {
                let bookingFoodId = Math.floor(10000000 + Math.random() * 90000000).toString();

                await db.promise().query(
                    `INSERT INTO bookingfoods (BookingFoodID, BookingID, FoodID, Quantity, Price, QRCode) VALUES (?, ?, ?, ?, ?, ?)`, 
                    [bookingFoodId, bookingId, food.id, food.quantity, food.price, finalBookingCode] 
                );
            }
        }

        // =======================================================
        // 🎫 TRỪ SỐ LƯỢNG VOUCHER ĐI 1 (NẾU DÙNG THÀNH CÔNG)
        // =======================================================
        if (finalVoucherId) {
            await db.promise().query(
                `UPDATE vouchers SET Quantity = Quantity - 1 WHERE VoucherID = ? AND Quantity > 0`, 
                [finalVoucherId]
            );
        }

        // 5. Trả ID và tổng tiền về cho Flutter để mang đi thanh toán
        res.status(200).json({ bookingId: bookingId.toString(), finalAmount: finalAmount });
    } catch (error) {
        console.error("❌ LỖI KHI TẠO ĐƠN NHÁP:", error); 
        res.status(500).json({ error: "Lỗi lưu Database" });
    }
});

// 3. API: TẢI SƠ ĐỒ GHẾ VÀ BẢN VẼ TỪ ADMIN (LAYOUT DATA)
router.get('/api/seats/:showtimeId', async (req, res) => {
    const showtimeId = req.params.showtimeId;
    console.log(`\n🔥 ---> ĐÃ VÀO PAYMENT.ROUTE! API LẤY SƠ ĐỒ GHẾ CHO SUẤT: ${showtimeId} <--- 🔥`);
    
    try {
        await db.promise().query(`DELETE FROM seatholds WHERE ExpiredAt <= NOW()`);

        const sqlSeats = `
            SELECT s.SeatID, s.SeatNumber, 
                   stype.TypeName AS SeatType,
                   CASE 
                       WHEN bs.SeatID IS NOT NULL THEN 'Occupied' 
                       WHEN sh.SeatID IS NOT NULL THEN 'Holding' 
                       ELSE 'Available' 
                   END AS status
            FROM seats s
            JOIN showtimes st ON s.RoomID = st.RoomID
            JOIN seattypes stype ON s.SeatTypeID = stype.SeatTypeID
            LEFT JOIN bookingseats bs ON s.SeatID = bs.SeatID AND bs.ShowtimeID = ? AND bs.Status IN ('Occupied', 'Pending')
            LEFT JOIN seatholds sh ON s.SeatID = sh.SeatID AND sh.ShowtimeID = ? 
            WHERE st.ShowtimeID = ?
        `;
        const [seats] = await db.promise().query(sqlSeats, [showtimeId, showtimeId, showtimeId]);

        const sqlLayout = `
            SELECT r.LayoutData 
            FROM rooms r 
            JOIN showtimes st ON r.RoomID = st.RoomID 
            WHERE st.ShowtimeID = ?
        `;
        const [layoutRes] = await db.promise().query(sqlLayout, [showtimeId]);
        const layoutData = layoutRes.length > 0 ? layoutRes[0].LayoutData : null;

        // 🚀 ĐỌC SỐ LƯỢNG GHẾ TỪ BẢNG SETTINGS (KEY-VALUE)
        let limitSeats = 8; 
        try {
            const [settings] = await db.promise().query("SELECT ConfigValue FROM systemconfigs WHERE ConfigKey = 'maxTicketsPerOrder' LIMIT 1");
            if (settings.length > 0 && settings[0].ConfigValue != null) {
                limitSeats = parseInt(settings[0].ConfigValue);
                console.log(`✅ Lấy thành công max_seats từ DB: ${limitSeats}`);
            }
        } catch (err) {
            console.log(`❌ Lỗi truy vấn bảng settings: ${err.message}`);
        }

        // 🚀 CỤC DATA TRẢ VỀ CÓ MAX_SEATS
        res.json({
            layoutData: layoutData,
            seats: seats,
            max_seats: limitSeats 
        });

    } catch (error) {
        console.error("Lỗi tải sơ đồ ghế:", error);
        res.status(500).json({ error: error.message });
    }
});


// 🚀 HÀM GỬI EMAIL TỰ ĐỘNG (GIAO DIỆN CHUYÊN NGHIỆP + CHÍNH SÁCH ĐỘNG + CHỐNG SPAM)
async function sendTicketEmail(data) {
    try {
        // 1. Móc thêm 'allowRefund' và 'refundBeforeHours' từ DB lên
        const [rows] = await db.promise().query(
            "SELECT ConfigKey, ConfigValue FROM systemconfigs WHERE ConfigKey IN ('smtpHost', 'smtpPort', 'smtpUser', 'smtpPass', 'hotline', 'cinemaName', 'allowRefund', 'refundBeforeHours')"
        );

        const config = {};
        rows.forEach(row => { config[row.ConfigKey] = row.ConfigValue; });

        const smtpHost = config.smtpHost;       
        const smtpPort = parseInt(config.smtpPort) || 587; 
        const smtpUser = config.smtpUser;       
        const smtpPass = config.smtpPass;   
        const sysHotline = config.hotline || "1900 1234";    
        const sysName = config.cinemaName || "CinemaTickets";
        
        // 🚀 XỬ LÝ CHÍNH SÁCH HOÀN VÉ TỰ ĐỘNG
        const isRefundAllowed = config.allowRefund === 'true' || config.allowRefund === '1';
        const refundHours = parseInt(config.refundBeforeHours) || 12; // Mặc định 12 tiếng nếu lỡ DB bị trống
        
        let refundPolicyText = "Vé đã mua không thể hoàn/hủy theo quy định của hệ thống.";
        if (isRefundAllowed) {
            refundPolicyText = `Hỗ trợ hoàn tiền nếu yêu cầu trước giờ chiếu ít nhất <strong>${refundHours} tiếng</strong>.`;
        }

        if (!smtpHost || !smtpUser || !smtpPass) return;

        let transporter = nodemailer.createTransport({
            host: smtpHost,
            port: smtpPort,
            secure: smtpPort == 465, 
            auth: { user: smtpUser, pass: smtpPass },
        });

        // ======================================================
        // 🚀 THIẾT KẾ TEMPLATE HTML CHUẨN RẠP PHIM LỚN
        // ======================================================
        const formatCurrency = new Intl.NumberFormat('vi-VN').format(data.totalAmount);
        
       // Tạo URL QR Code
        const qrCodeUrl = `https://quickchart.io/qr?text=${encodeURIComponent(data.ticketCode)}&size=150`;

        let mailOptions = {
            from: `"${sysName}" <${smtpUser}>`,
            to: data.email,
            subject: `${sysName} - Xác nhận đặt vé thành công - Mã đặt vé: #${data.ticketCode}`,
            
            // 🚀 TUYỆT CHIÊU CUỐI: Đính kèm file ảnh trực tiếp vào Email (Không sợ Google chặn)
            attachments: [
                {
                    filename: 'qrcode.png',
                    path: qrCodeUrl,         // Nodemailer sẽ tự động tải ảnh từ link này về Server...
                    cid: 'qrcode_ticket'     // ...sau đó gán cho nó cái mã ID này để nhúng vào HTML
                }
            ],

            html: `
            <div style="background-color: #f4f6f9; padding: 20px; font-family: Arial, sans-serif; line-height: 1.6;">
                <div style="max-width: 600px; margin: auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.05);">
                    
                    <!-- HEADER -->
                    <div style="background-color: #1e3a8a; padding: 25px; text-align: center; color: #ffffff;">
                        <h1 style="margin: 0; font-size: 26px; font-weight: 800; letter-spacing: 1px;">${sysName.toUpperCase()}</h1>
                        <p style="margin: 8px 0 0; font-size: 16px; opacity: 0.9;">🎉 Xác nhận đặt vé thành công</p>
                    </div>
                    
                    <!-- BODY -->
                    <div style="padding: 30px;">
                        <p style="font-size: 16px; color: #333;">Chào <strong>${data.customerName}</strong>,</p>
                        <p style="font-size: 16px; color: #555; margin-bottom: 25px;">Cảm ơn bạn đã đặt vé tại <strong>${data.cinemaName}</strong>. Giao dịch của bạn đã hoàn tất thành công.</p>
                        
                        <!-- MÃ VÉ & QR CODE -->
                        <div style="text-align: center; margin: 30px auto; padding: 20px 10px; border: 2px dashed #1e3a8a; border-radius: 12px; background-color: #f8fafc; max-width: 260px; box-sizing: border-box;">
                            <p style="margin: 0 0 5px; font-size: 13px; color: #64748b; font-weight: bold; text-transform: uppercase;">Mã đặt vé (Booking Code)</p>
                            <h2 style="margin: 0 0 15px; font-size: 26px; color: #d97706; letter-spacing: 1px; word-wrap: break-word;">${data.ticketCode}</h2>
                            
                            <!-- 🚀 CHÚ Ý CHỖ NÀY: Dùng cid:qrcode_ticket thay vì link URL -->
                            <img src="cid:qrcode_ticket" alt="Mã QR Vé: ${data.ticketCode}" width="150" height="150" style="display: block; margin: 0 auto; border-radius: 8px; border: 4px solid #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.1); max-width: 100%; height: auto;" />
                        </div>
                        
                        <!-- CHI TIẾT SUẤT CHIẾU -->
                        <h3 style="border-bottom: 2px solid #f1f5f9; padding-bottom: 10px; color: #1e3a8a; margin-top: 35px; font-size: 18px;">🎬 Thông tin chi tiết suất chiếu</h3>
                        <table style="width: 100%; border-collapse: collapse; margin-bottom: 25px; font-size: 15px;">
                            <tr><td style="padding: 10px 0; color: #64748b; width: 40%;">Tên phim:</td><td style="padding: 10px 0; font-weight: bold; color: #1e293b;">${data.movieName} <span style="font-size: 13px; font-weight: normal; color: #fff; background: #3b82f6; padding: 2px 6px; border-radius: 4px; margin-left: 5px;">${data.movieFormat}</span></td></tr>
                            <tr><td style="padding: 10px 0; color: #64748b; border-top: 1px solid #f1f5f9;">Rạp chiếu:</td><td style="padding: 10px 0; font-weight: bold; color: #1e293b; border-top: 1px solid #f1f5f9;">${data.cinemaName} - ${data.roomName}</td></tr>
                            <tr><td style="padding: 10px 0; color: #64748b; border-top: 1px solid #f1f5f9;">Thời gian:</td><td style="padding: 10px 0; font-weight: bold; color: #e11d48; border-top: 1px solid #f1f5f9;">${data.showTime}</td></tr>
                            <tr><td style="padding: 10px 0; color: #64748b; border-top: 1px solid #f1f5f9;">Ghế ngồi:</td><td style="padding: 10px 0; font-weight: bold; color: #1e293b; border-top: 1px solid #f1f5f9;">${data.seats}</td></tr>
                            <tr><td style="padding: 10px 0; color: #64748b; border-top: 1px solid #f1f5f9;">Combo bắp nước:</td><td style="padding: 10px 0; font-weight: bold; color: #1e293b; border-top: 1px solid #f1f5f9;">${data.foods}</td></tr>
                        </table>
                        
                        <!-- THÔNG TIN THANH TOÁN -->
                        <h3 style="border-bottom: 2px solid #f1f5f9; padding-bottom: 10px; color: #1e3a8a; margin-top: 30px; font-size: 18px;">💳 Thông tin thanh toán</h3>
                        <table style="width: 100%; border-collapse: collapse; margin-bottom: 30px; font-size: 15px;">
                            <tr><td style="padding: 10px 0; color: #64748b; width: 40%;">Phương thức:</td><td style="padding: 10px 0; font-weight: bold; color: #1e293b;">${data.paymentMethod}</td></tr>
                            <tr><td style="padding: 10px 0; color: #64748b; border-top: 1px solid #f1f5f9;">Tổng số tiền:</td><td style="padding: 10px 0; font-weight: bold; color: #e11d48; font-size: 16px; border-top: 1px solid #f1f5f9;">${formatCurrency} VNĐ</td></tr>
                            <tr><td style="padding: 10px 0; color: #64748b; border-top: 1px solid #f1f5f9;">Trạng thái:</td><td style="padding: 10px 0; font-weight: bold; color: #16a34a; border-top: 1px solid #f1f5f9;">✅ Đã thanh toán thành công</td></tr>
                        </table>
                        
                        <!-- HƯỚNG DẪN NHẬN VÉ -->
                        <div style="background-color: #f0fdf4; padding: 20px; border-left: 5px solid #16a34a; border-radius: 6px;">
                            <h4 style="margin-top: 0; margin-bottom: 15px; color: #166534; font-size: 16px;">🎟️ Hướng dẫn nhận vé tại rạp:</h4>
                            <ul style="margin-bottom: 0; padding-left: 20px; color: #14532d; font-size: 14px; line-height: 1.8;">
                                <li><strong>Cách 1:</strong> Đến máy xuất vé tự động, nhập Mã đặt vé hoặc quét Mã QR.</li>
                                <li><strong>Cách 2:</strong> Đưa màn hình email này cho nhân viên tại quầy vé để nhận vé cứng.</li>
                                <li style="color: #991b1b; font-weight: bold;">Lưu ý: Vui lòng đến trước giờ chiếu từ 10 - 15 phút.</li>
                            </ul>
                        </div>
                    </div>
                    
                    <!-- FOOTER -->
                    <div style="background-color: #f8fafc; padding: 25px; text-align: center; font-size: 13px; color: #64748b; border-top: 1px solid #e2e8f0;">
                        <p style="margin: 0 0 8px;">📞 Hotline hỗ trợ: <strong>${sysHotline}</strong></p>
                        <p style="margin: 0 0 15px;">⚠️ <strong>Chính sách:</strong> ${refundPolicyText}</p>
                        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 15px 0;">
                        <p style="margin: 0; font-size: 12px;">© 2026 ${sysName}. All rights reserved.</p>
                        <p style="margin: 5px 0 0; font-size: 10px; color: #cbd5e1;">Mã giao dịch hệ thống: ${new Date().getTime()}</p>
                    </div>
                </div>
            </div>
            `
        };

        await transporter.sendMail(mailOptions);
        console.log("✅ Đã gửi email thành công tới: " + data.email);

    } catch (error) {
        console.error("❌ Lỗi gửi email:", error.message);
    }
}

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