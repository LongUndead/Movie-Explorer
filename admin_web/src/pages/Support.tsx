import React, { useState } from 'react';
import Swal from 'sweetalert2';
import { Phone, Mail, MessageCircle, Send, Bug, Lightbulb, ShieldAlert } from 'lucide-react';

const Support = () => {
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [priority, setPriority] = useState('Bình thường');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!subject || !message) {
      Swal.fire('Thiếu thông tin', 'Vui lòng nhập tiêu đề và nội dung cần hỗ trợ!', 'warning');
      return;
    }

    setIsSubmitting(true);
    
    // Giả lập thời gian gửi yêu cầu tới server IT
    setTimeout(() => {
      setIsSubmitting(false);
      Swal.fire({
        title: 'Đã gửi yêu cầu!',
        text: 'Đội ngũ IT đã nhận được thông báo và sẽ xử lý trong thời gian sớm nhất.',
        icon: 'success',
        confirmButtonColor: '#2563eb'
      });
      setSubject('');
      setMessage('');
      setPriority('Bình thường');
    }, 1500);
  };

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] animate-[fade-in_0.3s_ease-out]">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* CỘT TRÁI: THÔNG TIN LIÊN HỆ NHANH */}
        <div className="lg:col-span-1 flex flex-col gap-4">
          <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
            <h3 className="font-bold text-slate-800 mb-4 flex items-center gap-2">
              <Phone size={18} className="text-blue-500" /> Hotline Khẩn Cấp
            </h3>
            <p className="text-2xl font-black text-blue-600 tracking-tight">1900 9999</p>
            <p className="text-sm text-slate-500 mt-1">Trực sự cố server 24/7</p>
          </div>

          <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
            <h3 className="font-bold text-slate-800 mb-4 flex items-center gap-2">
              <Mail size={18} className="text-emerald-500" /> Email Kỹ Thuật
            </h3>
            <p className="text-lg font-bold text-slate-700">it.support@cinemanage.vn</p>
            <p className="text-sm text-slate-500 mt-1">Phản hồi trong vòng 2-4 giờ</p>
          </div>

          <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
            <h3 className="font-bold text-slate-800 mb-4 flex items-center gap-2">
              <MessageCircle size={18} className="text-purple-500" /> Nhóm Zalo Nội Bộ
            </h3>
            <button className="w-full py-2.5 bg-purple-50 hover:bg-purple-100 text-purple-700 font-bold rounded-xl transition-colors border border-purple-200">
              Mở Zalo Chat
            </button>
          </div>
        </div>

        {/* CỘT PHẢI: FORM GỬI YÊU CẦU */}
        <div className="lg:col-span-2 bg-white p-8 rounded-2xl shadow-sm border border-slate-200">
          <h3 className="text-lg font-bold text-slate-800 mb-6 border-b border-slate-100 pb-4">Tạo Phiếu Hỗ Trợ (Ticket)</h3>
          
          <form onSubmit={handleSubmit} className="flex flex-col gap-5">
            {/* Tiêu đề */}
            <div>
              <label className="block text-sm font-bold text-slate-700 mb-2">Tiêu đề sự cố / Yêu cầu</label>
              <input 
                type="text" 
                placeholder="VD: Không xuất được báo cáo doanh thu ngày 15/12..."
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all"
              />
            </div>

            {/* Mức độ ưu tiên */}
            <div>
              <label className="block text-sm font-bold text-slate-700 mb-2">Mức độ nghiêm trọng</label>
              <div className="flex flex-wrap gap-3">
                <label className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-xl border cursor-pointer transition-all ${priority === 'Bình thường' ? 'bg-blue-50 border-blue-500 text-blue-700 font-bold' : 'bg-white border-slate-200 text-slate-500 hover:bg-slate-50'}`}>
                  <input type="radio" name="priority" value="Bình thường" className="hidden" checked={priority === 'Bình thường'} onChange={() => setPriority('Bình thường')} />
                  <Lightbulb size={18} /> Bình thường
                </label>
                <label className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-xl border cursor-pointer transition-all ${priority === 'Lỗi (Bug)' ? 'bg-amber-50 border-amber-500 text-amber-700 font-bold' : 'bg-white border-slate-200 text-slate-500 hover:bg-slate-50'}`}>
                  <input type="radio" name="priority" value="Lỗi (Bug)" className="hidden" checked={priority === 'Lỗi (Bug)'} onChange={() => setPriority('Lỗi (Bug)')} />
                  <Bug size={18} /> Lỗi (Bug)
                </label>
                <label className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-xl border cursor-pointer transition-all ${priority === 'Khẩn cấp' ? 'bg-red-50 border-red-500 text-red-700 font-bold' : 'bg-white border-slate-200 text-slate-500 hover:bg-slate-50'}`}>
                  <input type="radio" name="priority" value="Khẩn cấp" className="hidden" checked={priority === 'Khẩn cấp'} onChange={() => setPriority('Khẩn cấp')} />
                  <ShieldAlert size={18} /> Khẩn cấp
                </label>
              </div>
            </div>

            {/* Nội dung */}
            <div>
              <label className="block text-sm font-bold text-slate-700 mb-2">Mô tả chi tiết</label>
              <textarea 
                rows={5}
                placeholder="Mô tả rõ các bước dẫn đến lỗi hoặc tính năng bạn muốn thêm..."
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:ring-4 focus:ring-blue-50 focus:border-blue-500 outline-none transition-all resize-none"
              ></textarea>
            </div>

            {/* Nút gửi */}
            <div className="flex justify-end mt-2">
              <button 
                type="submit"
                disabled={isSubmitting}
                className="flex items-center gap-2 px-8 py-3.5 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-xl shadow-md shadow-blue-200 transition-all active:scale-95 disabled:opacity-70"
              >
                {isSubmitting ? <span className="animate-spin text-lg">↻</span> : <Send size={18} />}
                {isSubmitting ? 'Đang gửi...' : 'Gửi Yêu Cầu Hỗ Trợ'}
              </button>
            </div>
          </form>
          
        </div>
      </div>
    </div>
  );
};

export default Support;