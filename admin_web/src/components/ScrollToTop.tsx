import React, { useState, useEffect } from 'react';
import { ChevronUp } from 'lucide-react';

const ScrollToTop = () => {
  const [isVisible, setIsVisible] = useState(false);

  // Lắng nghe sự kiện cuộn chuột
  useEffect(() => {
    // 🚀 CHỖ SỬA 3: Tìm đúng cái div đang cuộn
    const scrollContainer = document.getElementById('main-content');
    if (!scrollContainer) return;

    const toggleVisibility = () => {
      if (scrollContainer.scrollTop > 300) {
        setIsVisible(true);
      } else {
        setIsVisible(false);
      }
    };

    scrollContainer.addEventListener('scroll', toggleVisibility);
    return () => scrollContainer.removeEventListener('scroll', toggleVisibility);
  }, []);

  const scrollToTop = () => {
    const scrollContainer = document.getElementById('main-content');
    if (scrollContainer) {
      scrollContainer.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };
  return (
    <button
      onClick={scrollToTop}
      // Dùng class "group" để điều khiển hiệu ứng của icon bên trong
      className={`group fixed bottom-8 right-8 z-[9999] p-3.5 rounded-full flex items-center justify-center transition-all duration-500 ease-out
        ${
          isVisible 
            ? 'opacity-100 translate-y-0 cursor-pointer shadow-[0_8px_20px_rgba(79,70,229,0.3)] bg-indigo-600' 
            : 'opacity-0 translate-y-10 pointer-events-none bg-indigo-300' // Bắt đầu từ vị trí sâu hơn (translate-y-10)
        }
        hover:bg-indigo-500 hover:scale-110 hover:shadow-[0_0_25px_rgba(79,70,229,0.7)] active:scale-95
      `}
      title="Cuộn lên đầu trang"
    >
      <ChevronUp 
        size={24} 
        strokeWidth={3} 
        // Hiệu ứng mũi tên nảy lên khi trỏ chuột vào nút
        className="text-white transition-transform duration-300 group-hover:-translate-y-1" 
      />
    </button>
  );
};

export default ScrollToTop;