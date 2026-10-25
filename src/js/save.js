// localStorage 저장. 접근이 막혀도(사생활 보호 창 등) 던지지 않는다.
const KEY = 'cheoyongmu.save';
const fresh = () => ({ night: 1, masks: {}, best: {} });

export const Save = {
  KEY,
  load() {
    try {
      const o = JSON.parse(localStorage.getItem(KEY));
      if (o && typeof o === 'object') {
        return {
          night: Math.min(5, Math.max(1, o.night | 0 || 1)),
          masks: o.masks && typeof o.masks === 'object' ? o.masks : {},
          best: o.best && typeof o.best === 'object' ? o.best : {},
        };
      }
    } catch (e) { /* 저장 없음·깨짐 */ }
    return fresh();
  },
  write(data) { try { localStorage.setItem(KEY, JSON.stringify(data)); return true; } catch (e) { return false; } },
  clear() { try { localStorage.removeItem(KEY); } catch (e) { /* 무시 */ } },
};
