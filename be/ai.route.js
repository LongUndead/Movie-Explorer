const express = require('express');
const router = express.Router();
const Groq = require("groq-sdk");
const db = require('./db'); // Đừng quên dòng này để chọc vào MySQL nha

// Khởi tạo Groq (Lấy key tự động từ file .env)
const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ==========================================
// 🚀 API: TỰ ĐỘNG VIẾT MÔ TẢ PHIM (CHO ADMIN)
// ==========================================
router.post('/generate-movie-desc', async (req, res) => {
    const { movieName, genre } = req.body;

    if (!movieName || !genre) {
        return res.status(400).json({ error: "Thiếu tên phim hoặc thể loại!" });
    }

    try {
        const chatCompletion = await groq.chat.completions.create({
            messages: [
                {
                    role: "system",
                    content: "Bạn là một chuyên gia content marketing cho hệ thống rạp chiếu phim CinemaTickets. Bạn luôn viết nội dung cực kỳ lôi cuốn, giật gân, chuẩn SEO, có sử dụng emoji phù hợp để kích thích người xem mua vé."
                },
                {
                    role: "user",
                    content: `Hãy viết 1 đoạn mô tả hấp dẫn (khoảng 3 câu) để quảng cáo cho bộ phim "${movieName}", thể loại "${genre}".`
                }
            ],
            model: "llama-3.1-8b-instant", 
            temperature: 0.7, 
        });

        const aiContent = chatCompletion.choices[0]?.message?.content;
        
        // Trả kết quả về cho Frontend
        res.json({ success: true, content: aiContent });

    } catch (error) {
        console.error("Lỗi gọi Groq API:", error);
        res.status(500).json({ error: "Lỗi hệ thống khi sinh nội dung bằng AI" });
    }
});
// Thêm hàm tính khoảng cách (Công thức Haversine) ở ngay trên API
function calculateDistance(lat1, lon1, lat2, lon2) {
    if (!lat1 || !lon1 || !lat2 || !lon2) return null;
    const R = 6371; // Bán kính trái đất (km)
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return (R * c).toFixed(1); // Trả về số km (ví dụ: 2.5)
}

// ==========================================
// 🚀 API: CHATBOT CHO USER (HOÀN THIỆN 100%)
// ==========================================
router.post('/chat', async (req, res) => {
    const { message, userName, lat, lng } = req.body;
    if (!message) return res.status(400).json({ error: "Không có tin nhắn" });

    try {
        const lowerMsg = message.toLowerCase();

        // -----------------------------------------------------------------
        // 🛡️ CHẶN 1: KHÁCH HỎI SUẤT CHIẾU -> BẺ LÁI NGAY LẬP TỨC 
        // -----------------------------------------------------------------
        if (lowerMsg.includes('suất chiếu') || lowerMsg.includes('lịch chiếu') || lowerMsg.includes('mấy giờ chiếu')) {
            return res.json({
                reply: "Dạ, vì lịch chiếu và ghế trống được hệ thống cập nhật liên tục từng giây. Để xem chính xác các suất chiếu mới nhất, bạn vui lòng chọn trực tiếp Phim hoặc Rạp ở phần gợi ý bên dưới nhé! 🥰",
                type: "text",
                data: []
            });
        }

        // -----------------------------------------------------------------
        // 🛡️ CHẶN 2: TÌM RẠP & TẠO CÂU SQL TÌM BẮP NƯỚC
        // -----------------------------------------------------------------
        const brandKeywords = {'cgv': 1, 'galaxy': 2, 'lotte': 3, 'bhd': 4, 'cinestar': 5, 'mega': 6, 'megags': 6, 'dcine': 7, 'beta': 8, 'aeon': 9};
        let targetBrandId = null;
        let targetBrandName = '';
        for (const [key, id] of Object.entries(brandKeywords)) {
            if (lowerMsg.includes(key)) {
                targetBrandId = id;
                targetBrandName = key;
                break;
            }
        }

        // 🚀 BỔ SUNG LẠI KHAI BÁO BIẾN BỊ THIẾU Ở ĐÂY
        let foodQuery = 'SELECT FoodID as id, Name, Price, description, ImageURL, brand_id FROM foods LIMIT 15';
        let queryParams = [];
        if (targetBrandId) {
            foodQuery = 'SELECT FoodID as id, Name, Price, description, ImageURL, brand_id FROM foods WHERE brand_id = ? LIMIT 15';
            queryParams = [targetBrandId];
        }

        const isFoodQuery = lowerMsg.includes('món') || lowerMsg.includes('bắp') || lowerMsg.includes('nước') || lowerMsg.includes('combo') || lowerMsg.includes('đồ ăn');
        const isBranchSelected = lowerMsg.includes('đã chọn chi nhánh:'); 

        // Bước 2.1: Khách hỏi bắp nước của rạp -> Bắt chọn chi nhánh trước
        if (isFoodQuery && targetBrandId && !isBranchSelected) {
            const brandMap = {1: 'CGV', 2: 'Galaxy', 3: 'Lotte', 4: 'BHD', 5: 'Cinestar', 6: 'Mega GS', 7: 'DCine', 8: 'Beta', 9: 'AEON BETA'};
            const actualBrandName = brandMap[targetBrandId];
            const [brandCinemas] = await db.promise().query('SELECT id, name, address, latitude, longitude FROM cinemas WHERE name LIKE ? AND IsDeleted = 0 LIMIT 10', [`%${actualBrandName}%`]);
            
            return res.json({
                reply: `Trợ lý tìm thấy các chi nhánh của ${actualBrandName}. Bạn muốn xem menu bắp nước tại chi nhánh nào ạ? 👇`,
                type: 'cinema_for_food',
                data: brandCinemas
            });
        }

        // Bước 2.2: Khách đã bấm chọn chi nhánh -> In ra bắp nước của rạp đó
        if (isBranchSelected) {
            const match = message.match(/brand: (\d+)/);
            const bId = match ? match[1] : 1;
            const cinemaNameMatch = message.match(/chi nhánh: (.*?) \|/i);
            const cinemaNameStr = cinemaNameMatch ? cinemaNameMatch[1] : 'rạp này';

            const [foods] = await db.promise().query('SELECT FoodID as id, Name, Price, description, ImageURL, brand_id FROM foods WHERE brand_id = ? LIMIT 15', [bId]);
            
            return res.json({
                reply: `Dưới đây là menu bắp nước thơm ngon tại ${cinemaNameStr}! 🍿🥤`,
                type: 'food',
                data: foods
            });
        }

        // ----------------------------------------------------
        // 🚀 BƯỚC 3: QUERY DATABASE CHO AI 
        // ----------------------------------------------------
        const [cinemas] = await db.promise().query('SELECT id, name, address, latitude, longitude FROM cinemas WHERE IsDeleted = 0 LIMIT 10');
        const [movies] = await db.promise().query('SELECT id, title, genres, release_date FROM movies WHERE IsDeleted = 0 ORDER BY release_date DESC LIMIT 15'); 
        const [vouchers] = await db.promise().query('SELECT VoucherID as id, Code as name, DiscountPercent as discount FROM vouchers WHERE Quantity > 0 AND ExpiredAt > NOW() LIMIT 5');
        const [foods] = await db.promise().query(foodQuery, queryParams); // Đã hết lỗi Not Defined

        // KHAI BÁO CÁC BIẾN CONTEXT 
        const cinemaContext = cinemas.map(c => {
            let distStr = "";
            if (lat && lng && c.latitude && c.longitude) {
                const km = calculateDistance(lat, lng, c.latitude, c.longitude);
                distStr = `| Cách khách hàng: ${km} km`; 
            }
            return `- ID: ${c.id} | Rạp: ${c.name} | Địa chỉ: ${c.address} ${distStr}`;
        }).join('\n');

        const movieContext = movies.map(m => {
            let dateStr = "Đang cập nhật";
            if (m.release_date) {
                const d = new Date(m.release_date);
                dateStr = `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`;
            }
            return `- ID: ${m.id} | Phim: ${m.title} | Thể loại: ${m.genres} | Khởi chiếu: ${dateStr}`;
        }).join('\n');

        const voucherContext = vouchers.map(v => `- ID: ${v.id} | Mã: ${v.name} | Giảm: ${v.discount}%`).join('\n');
        
        const brandMap = {1: 'CGV', 2: 'Galaxy', 3: 'Lotte', 4: 'BHD', 5: 'Cinestar', 6: 'Mega GS', 7: 'DCine', 8: 'Beta', 9: 'AEON BETA'};
        const foodContext = foods.map(f => `- ID: ${f.id} | Thuộc Rạp: ${brandMap[f.brand_id] || 'Khác'} | Món: ${f.Name}`).join('\n');

        // ----------------------------------------------------
        // 🚀 BƯỚC 4: PROMPT "KHOÁ CHẶT AI" 
        // ----------------------------------------------------
        const systemPrompt = `
        Bạn là "Trợ lý ăn chơi" cực kỳ nhiệt tình và sành sỏi tại hệ thống rạp chiếu phim CinemaTickets. 
        Tên khách hàng: "${userName || 'bạn'}". Hãy xưng hô thân thiện bằng tên khách.

        DƯỚI ĐÂY LÀ DANH SÁCH DỮ LIỆU CHUẨN TỪ HỆ THỐNG CỦA BẠN:
        
        🎬 RẠP (kèm khoảng cách thực tế):
        ${cinemaContext}

        🍿 PHIM (kèm ngày khởi chiếu):
        ${movieContext}
        
        🎁 KHUYẾN MÃI:
        ${voucherContext}

        🍔 BẮP NƯỚC (Đã được lọc theo ý khách):
        ${foodContext}

        NHIỆM VỤ BẮT BUỘC: Hãy trả về phản hồi dưới định dạng JSON sau:
        {
            "reply": "Đoạn văn tư vấn nhiệt tình, mặn mòi, có sử dụng emoji, giải đáp ĐÚNG trọng tâm câu hỏi.",
            "response_type": "Chọn 1 loại chuẩn: 'movie', 'cinema', 'voucher', 'food', hoặc 'text'",
            "item_ids": [Mảng chứa các số ID nguyên lấy ĐÚNG từ DANH SÁCH DỮ LIỆU CHUẨN ở trên]
        }

        CÁC QUY TẮC NGHIÊM NGẶT (TUYỆT ĐỐI KHÔNG LÀM SAI):
        - Quy tắc Bắp nước: Nếu khách hỏi đồ ăn, trả về type "food". CHỈ ĐƯỢC LẤY ID nằm trong mục [🍔 BẮP NƯỚC]. Tuyệt đối không bịa ID khác.
        - Quy tắc Phim: Nếu hỏi phim/tháng chiếu, trả về type "movie". Dựa vào ngày khởi chiếu trong mục [🍿 PHIM] để lọc và trả về ID chuẩn.
        - Quy tắc Suất chiếu: Nếu khách hỏi về Giờ chiếu / Suất chiếu / Hôm nay có phim gì. TUYỆT ĐỐI KHÔNG trả về type "movie". Bắt buộc trả về type "text" và ghi reply: "Dạ, vì lịch chiếu được cập nhật liên tục, để xem chính xác các suất chiếu vào thời gian bạn muốn, ${userName || 'bạn'} vui lòng chọn trực tiếp Phim hoặc Rạp ở phần gợi ý bên dưới nhé! 🥰".
        - Quy tắc Rạp: Nếu hỏi rạp gần/xa, trả về type "cinema". Tự phân tích số km trong mục [🎬 RẠP] để tìm ra rạp phù hợp nhất và trả về ID của rạp đó.
        `;

        const chatCompletion = await groq.chat.completions.create({
            messages: [
                { role: "system", content: systemPrompt },
                { role: "user", content: message }
            ],
            model: "llama-3.1-8b-instant", 
            temperature: 0.1, 
            max_tokens: 500, 
            response_format: { type: "json_object" } 
        });

        const aiResponse = JSON.parse(chatCompletion.choices[0]?.message?.content);
        
        let returnedData = [];
        const ids = aiResponse.item_ids || [];

        // 🚀 ĐÃ BỔ SUNG LẠI TYPE 'food' VÀ 'cinema' Ở ĐÂY
        if (ids.length > 0) {
            if (aiResponse.response_type === 'movie') {
                const [rows] = await db.promise().query('SELECT * FROM movies WHERE id IN (?)', [ids]);
                returnedData = rows;
            } else if (aiResponse.response_type === 'cinema') {
                const [rows] = await db.promise().query('SELECT * FROM cinemas WHERE id IN (?)', [ids]);
                returnedData = rows;
            } else if (aiResponse.response_type === 'voucher') {
                const [rows] = await db.promise().query('SELECT VoucherID as id, Code, DiscountPercent, MaxDiscountAmount FROM vouchers WHERE VoucherID IN (?)', [ids]);
                returnedData = rows;
            } else if (aiResponse.response_type === 'food') {
                const [rows] = await db.promise().query('SELECT FoodID as id, Name, Price, description, ImageURL, brand_id FROM foods WHERE FoodID IN (?)', [ids]);
                returnedData = rows;
            }
        }

        res.json({ 
            reply: aiResponse.reply, 
            type: aiResponse.response_type, 
            data: returnedData 
        });

    } catch (error) {
        console.error("Lỗi Chat API:", error);
        res.status(500).json({ error: "Hệ thống bận!" });
    }
});

module.exports = router;