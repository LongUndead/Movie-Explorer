const mysql = require('mysql2');
require('dotenv').config();

const db = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT || 3306,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Chạy thử 1 query bằng callback để test
db.query("SELECT 1", (err) => {
    if (err) console.error('❌ Lỗi Pool MySQL:', err.message);
    else console.log('✅ Đã kết nối thành công Database bằng Pool!');
});

module.exports = db;