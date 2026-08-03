import React, { useState, useEffect } from 'react';
import axios from 'axios';
import Swal from 'sweetalert2';
import { 
  Settings as SettingsIcon, Ticket, Mail, Save, 
  Building2, Phone, MapPin, Clock, Eye, EyeOff, Loader2, AlertTriangle 
} from 'lucide-react';

const Toast = Swal.mixin({
  toast: true,
  position: 'top-end',
  showConfirmButton: false,
  timer: 3000,
  timerProgressBar: true,
  didOpen: (toast) => {
    toast.addEventListener('mouseenter', Swal.stopTimer);
    toast.addEventListener('mouseleave', Swal.resumeTimer);
  }
});

const ToggleSwitch = ({ label, checked, onToggle }: { label: string, checked: boolean, onToggle: () => void }) => (
  <div className="flex items-center justify-between p-4 bg-slate-50 border border-slate-200 rounded-xl">
    <span className="text-sm font-bold text-slate-700">{label}</span>
    <button
      type="button"
      onClick={onToggle}
      // Đã sửa màu: Bật là Xanh, Tắt là Xám
      className={`relative w-12 h-6 rounded-full transition-colors duration-300 focus:outline-none ${checked ? 'bg-emerald-500' : 'bg-slate-300'}`}
    >
      <span className={`absolute left-1 top-1 bg-white w-4 h-4 rounded-full transition-transform duration-300 ${checked ? 'translate-x-6' : 'translate-x-0'}`} />
    </button>
  </div>
);

// Format lại giờ để hiển thị chuẩn trên input
const formatDateForInput = (dateString?: string) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return '';
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
};

const Settings = () => {
  const [activeTab, setActiveTab] = useState<'GENERAL' | 'BOOKING' | 'SMTP'>('GENERAL');
  const [loading, setLoading] = useState(false);
  const [fetching, setFetching] = useState(true);
  const [showSmtpPass, setShowSmtpPass] = useState(false);

  const [config, setConfig] = useState({
    cinemaName: '', hotline: '', supportEmail: '', address: '', 
    maxTicketsPerOrder: 8, seatHoldMinutes: 15, allowRefund: false, refundBeforeHours: 24,
    smtpHost: '', smtpPort: 587, smtpUser: '', smtpPass: '',
    isMaintenanceMode: false,
    maintenanceEndTime: '',
    maintenanceMessage: 'Hệ thống đang bảo trì định kỳ. Vui lòng quay lại sau!'
  });

  useEffect(() => {
    const fetchConfig = async () => {
      try {
        const res = await axios.get('http://192.168.1.7:3000/api/admin/settings');
        const dbData = Array.isArray(res.data) ? res.data[0] : (res.data?.data || res.data);

        if (dbData && Object.keys(dbData).length > 0) {
           let fetchedMaintenanceMode = String(dbData.isMaintenanceMode) === '1' || String(dbData.isMaintenanceMode).toLowerCase() === 'true';
           let fetchedEndTime = formatDateForInput(dbData.maintenanceEndTime);

           // 🚀 THUẬT TOÁN THÔNG MINH: NẾU QUA GIỜ -> TỰ ĐỘNG ÉP CÔNG TẮC TẮT
           if (fetchedMaintenanceMode && dbData.maintenanceEndTime) {
              const endTimeObj = new Date(dbData.maintenanceEndTime).getTime();
              const nowObj = new Date().getTime();
              
              if (endTimeObj <= nowObj) {
                 fetchedMaintenanceMode = false; // Gạt công tắc về Đang hoạt động
                 fetchedEndTime = ''; // Xóa sạch cái giờ đã cũ đi
                 
                 // (Tùy chọn: Có thể ngầm lưu xuống DB ở đây, nhưng chỉ cần UI hiển thị đúng là Backend cũng tự hiểu rồi)
              }
           }

           setConfig(prev => ({ 
             ...prev, 
             cinemaName: dbData.cinemaName || '',
             hotline: dbData.hotline || '',
             supportEmail: dbData.supportEmail || '',
             address: dbData.address || '',
             maxTicketsPerOrder: dbData.maxTicketsPerOrder ?? 8,
             seatHoldMinutes: dbData.seatHoldMinutes ?? 15,
             refundBeforeHours: dbData.refundBeforeHours ?? 24,
             smtpHost: dbData.smtpHost || '',
             smtpPort: dbData.smtpPort ?? 587,
             smtpUser: dbData.smtpUser || '',
             smtpPass: dbData.smtpPass || '',
             allowRefund: dbData.allowRefund === 1 || dbData.allowRefund === true || dbData.allowRefund === '1',
             
             isMaintenanceMode: fetchedMaintenanceMode,
             maintenanceEndTime: fetchedEndTime,
             maintenanceMessage: dbData.maintenanceMessage || 'Hệ thống đang bảo trì định kỳ. Vui lòng quay lại sau!'
           }));
        }
      } catch (error) {
        Toast.fire({ icon: 'error', title: 'Không thể kết nối đến Database cấu hình' });
      } finally {
        setFetching(false);
      }
    };
    fetchConfig();
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target;
    setConfig(prev => ({
      ...prev,
      [name]: type === 'number' ? Number(value) : value
    }));
  };

  const handleToggle = (name: string) => {
    setConfig(prev => ({ ...prev, [name]: !(prev as any)[name] }));
  };

  const handleSave = async () => {
    setLoading(true);
    try {
      const payloadToSave = {
        ...config,
        allowRefund: config.allowRefund ? 1 : 0,
        isMaintenanceMode: config.isMaintenanceMode ? 1 : 0 
      };

      await axios.put('http://192.168.1.7:3000/api/admin/settings', payloadToSave);
      Toast.fire({ icon: 'success', title: 'Đã lưu cấu hình hệ thống!' });
    } catch (error) {
      Swal.fire('Lỗi hệ thống', 'Không thể lưu cấu hình vào Database!', 'error');
    } finally {
      setLoading(false);
    }
  };

  if (fetching) {
    return (
      <div className="flex items-center justify-center h-[calc(100vh-70px)] bg-slate-50">
        <Loader2 className="animate-spin text-blue-500" size={40} />
      </div>
    );
  }

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] animate-[fade-in_0.3s_ease-out]">
      
      <div className="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-4 rounded-2xl shadow-sm border border-slate-200">
        <div>
          <h1 className="text-xl font-black text-slate-800 m-0 flex items-center gap-2">
            <SettingsIcon className="text-blue-600" /> Cấu Hình Hệ Thống
          </h1>
          <p className="text-sm text-slate-500 mt-1 font-medium">Cập nhật và đồng bộ cấu hình từ Cơ sở dữ liệu.</p>
        </div>
        <button 
          onClick={handleSave}
          disabled={loading}
          className="w-full sm:w-auto bg-blue-600 hover:bg-blue-700 text-white px-6 py-2.5 rounded-xl font-bold text-sm flex items-center justify-center gap-2 transition-all hover:shadow-lg hover:shadow-blue-200 hover:-translate-y-0.5 active:translate-y-0 disabled:opacity-70 disabled:cursor-not-allowed"
        >
          {loading ? <Loader2 size={18} className="animate-spin" /> : <Save size={18} />}
          {loading ? 'Đang đồng bộ...' : 'Lưu Thay Đổi'}
        </button>
      </div>

      <div className="flex bg-slate-100 p-1.5 rounded-xl w-full overflow-x-auto no-scrollbar mb-6 shadow-sm border border-slate-200">
        {[
          { id: 'GENERAL', icon: Building2, label: 'Thông tin chung' },
          { id: 'BOOKING', icon: Ticket, label: 'Quy định đặt vé' },
          { id: 'SMTP', icon: Mail, label: 'Mail Server' }
        ].map(tab => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`flex items-center gap-2 px-5 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all duration-300 flex-1 justify-center ${
                isActive 
                  ? 'bg-white text-blue-700 shadow-sm transform scale-[1.02]' 
                  : 'text-slate-500 hover:text-slate-800 hover:bg-slate-200'
              }`}
            >
              <Icon size={16} className={isActive ? "text-blue-600" : "text-slate-400"} />
              {tab.label}
            </button>
          );
        })}
      </div>

      <div className="bg-white p-6 md:p-8 rounded-2xl shadow-sm border border-slate-200 min-h-[400px]">
        {activeTab === 'GENERAL' && (
          <div className="animate-[slide-in-top_0.3s_ease-out]">
            
            {/* 🚀 KHU VỰC BẢO TRÌ */}
            <div className={`mb-8 p-5 rounded-xl border-2 transition-all ${config.isMaintenanceMode ? 'bg-red-50 border-red-200' : 'bg-slate-50 border-slate-200'}`}>
              <div className="flex items-center justify-between mb-4">
                <h2 className={`text-lg font-bold flex items-center gap-2 ${config.isMaintenanceMode ? 'text-red-700' : 'text-slate-700'}`}>
                  <AlertTriangle size={20} /> Trạng Thái Hệ Thống
                </h2>
                <div className="flex items-center gap-3">
                  <span className={`text-sm font-bold ${config.isMaintenanceMode ? 'text-red-600' : 'text-emerald-600'}`}>
                    {config.isMaintenanceMode ? 'ĐANG BẢO TRÌ' : 'ĐANG HOẠT ĐỘNG'}
                  </span>
                  <button
                    type="button"
                    onClick={() => handleToggle('isMaintenanceMode')}
                    // Đảo ngược UI: Khi Đang hoạt động (!isMaintenanceMode) -> Bật Xanh lá. Khi Bảo trì -> Tắt màu Đỏ
                    className={`relative w-12 h-6 rounded-full transition-colors duration-300 focus:outline-none ${!config.isMaintenanceMode ? 'bg-emerald-500' : 'bg-red-500'}`}
                  >
                    <span className={`absolute left-1 top-1 bg-white w-4 h-4 rounded-full transition-transform duration-300 ${!config.isMaintenanceMode ? 'translate-x-6' : 'translate-x-0'}`} />
                  </button>
                </div>
              </div>
              
              {config.isMaintenanceMode && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 animate-[fade-in_0.3s_ease-out]">
                  <div className="group">
                    <label className="block text-[13px] font-bold text-red-700 mb-2">Dự kiến kết thúc lúc (Không bắt buộc)</label>
                    <input 
                      type="datetime-local" 
                      name="maintenanceEndTime" 
                      value={config.maintenanceEndTime} 
                      onChange={handleChange} 
                      className="w-full px-4 py-3 bg-white border border-red-200 rounded-xl outline-none focus:border-red-500 focus:ring-4 focus:ring-red-50 text-sm font-medium transition-all" 
                    />
                    <p className="text-[11px] text-red-500 mt-1">* Hệ thống sẽ TỰ ĐỘNG MỞ LẠI khi qua giờ này (Dù công tắc đang bật).</p>
                  </div>
                  <div className="group">
                    <label className="block text-[13px] font-bold text-red-700 mb-2">Lời nhắn cho khách hàng</label>
                    <textarea 
                      name="maintenanceMessage" 
                      value={config.maintenanceMessage} 
                      onChange={handleChange} 
                      rows={2}
                      placeholder="Hệ thống đang bảo trì, vui lòng quay lại sau..."
                      className="w-full px-4 py-3 bg-white border border-red-200 rounded-xl outline-none focus:border-red-500 focus:ring-4 focus:ring-red-50 text-sm font-medium transition-all resize-none" 
                    />
                  </div>
                </div>
              )}
            </div>

            <h2 className="text-lg font-bold text-slate-800 mb-6 pb-2 border-b border-slate-100">Thông Tin Liên Hệ Rạp</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Tên hệ thống rạp</label>
                <div className="relative">
                  <Building2 size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input type="text" name="cinemaName" value={config.cinemaName} onChange={handleChange} className="w-full pl-10 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all" />
                </div>
              </div>
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Hotline CSKH</label>
                <div className="relative">
                  <Phone size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input type="text" name="hotline" value={config.hotline} onChange={handleChange} className="w-full pl-10 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all" />
                </div>
              </div>
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Email Hỗ trợ</label>
                <div className="relative">
                  <Mail size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input type="email" name="supportEmail" value={config.supportEmail} onChange={handleChange} className="w-full pl-10 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all" />
                </div>
              </div>
              <div className="group md:col-span-2">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Địa chỉ Trụ sở chính</label>
                <div className="relative">
                  <MapPin size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input type="text" name="address" value={config.address} onChange={handleChange} className="w-full pl-10 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all" />
                </div>
              </div>
            </div>
          </div>
        )}

        {/* CÁC TAB KHÁC GIỮ NGUYÊN */}
        {activeTab === 'BOOKING' && (
          <div className="animate-[slide-in-top_0.3s_ease-out]">
            <h2 className="text-lg font-bold text-slate-800 mb-6 pb-2 border-b border-slate-100">Tham Số Nghiệp Vụ</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Giới hạn số vé tối đa / 1 lần mua</label>
                <input type="number" min="1" max="20" name="maxTicketsPerOrder" value={config.maxTicketsPerOrder} onChange={handleChange} className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all" />
              </div>
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Thời gian chờ thanh toán (Phút)</label>
                <div className="relative">
                  <Clock size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input type="number" min="1" name="seatHoldMinutes" value={config.seatHoldMinutes} onChange={handleChange} className="w-full pl-10 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all" />
                </div>
                <p className="text-[11px] text-slate-500 mt-1">Ghế sẽ tự động nhả nếu quá thời gian này.</p>
              </div>
            </div>

            <h2 className="text-lg font-bold text-slate-800 mb-4 pb-2 border-b border-slate-100">Chính Sách Hủy Vé</h2>
            <div className="flex flex-col gap-4">
              <ToggleSwitch 
                label="Cho phép Khách hàng tự hủy vé trên App" 
                checked={config.allowRefund} 
                onToggle={() => handleToggle('allowRefund')} 
              />
              {config.allowRefund && (
                <div className="group animate-[slide-in-top_0.2s_ease-out]">
                  <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Chỉ được phép hủy trước giờ chiếu (Giờ)</label>
                  <input type="number" min="1" name="refundBeforeHours" value={config.refundBeforeHours} onChange={handleChange} className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all md:w-1/2" />
                </div>
              )}
            </div>
          </div>
        )}

        {activeTab === 'SMTP' && (
          <div className="animate-[slide-in-top_0.3s_ease-out]">
            <h2 className="text-lg font-bold text-slate-800 mb-6 pb-2 border-b border-slate-100">Máy Chủ Gửi Mail (Email Server)</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Máy chủ (Host)</label>
                <input type="text" name="smtpHost" value={config.smtpHost} onChange={handleChange} placeholder="smtp.gmail.com" className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all" />
              </div>
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Cổng (Port)</label>
                <input type="number" name="smtpPort" value={config.smtpPort} onChange={handleChange} placeholder="587" className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all" />
              </div>
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Tài khoản (Tên đăng nhập / Email)</label>
                <input type="text" name="smtpUser" value={config.smtpUser} onChange={handleChange} placeholder="noreply@cinemanage.vn" className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all" />
              </div>
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-2 group-focus-within:text-blue-600 transition-colors">Mật khẩu (App Password)</label>
                <div className="relative">
                  <input type={showSmtpPass ? "text" : "password"} name="smtpPass" value={config.smtpPass} onChange={handleChange} placeholder="••••••••" className="w-full pl-4 pr-10 py-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all font-mono" />
                  <button type="button" onClick={() => setShowSmtpPass(!showSmtpPass)} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-blue-600 transition-colors">
                    {showSmtpPass ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

      </div>
    </div>
  );
};

export default Settings;