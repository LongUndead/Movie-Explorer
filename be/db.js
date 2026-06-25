const mysql = require('mysql2/promise');
require('dotenv').config(); 

const db = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER || 'root',      // Mặc định của XAMPP là root
    password: process.env.DB_PASS || '',  // Mặc định của XAMPP là rỗng
    
    // ⚠️ CHÚ Ý: Đổi chữ 'TEN_DATABASE_CUA_BAN' thành tên database thật trong phpMyAdmin của bạn nhé!
    database: process.env.DB_NAME || 'TEN_DATABASE_CUA_BAN', 
    
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Test thử kết nối
db.getConnection()
    .then(() => console.log("✅ Đã kết nối MySQL thành công từ file db.js!"))
    .catch((err) => console.error("❌ Lỗi kết nối MySQL:", err));

module.exports = db;