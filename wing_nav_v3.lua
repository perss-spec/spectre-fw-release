--[[============================================================
  БПЛА "КРЫЛО" — Навигация + Антиспуфинг v3.8.3
  Полётный контроллер: OrangeCube (ArduPlane)
  Параметры: Spectr_Cube+.param + param_changes.param
============================================================
  ИЗМЕНЕНИЯ v3.6:
    + ADD: S-поворот для кинематической верификации GPS (L7)
      Каждые 2 мин в CRUISE при TRUSTED GPS командуем ±15° отклонение курса.
      Если GPS velocity не отвечает поворотом — score += 25.
      Параметры: STURN_INTERVAL_MS, STURN_OFFSET_DEG, STURN_WAIT_MS, STURN_MEAS_MS, STURN_MIN_RESP

  ИЗМЕНЕНИЯ v3.8.3 (real-hardware fixes, 2026-02-27):
    + FIX КРИТИЧЕСКИЙ: ahrs:get_yaw_rad() → ahrs:get_yaw() — метод get_yaw_rad
      не существует в ArduPlane Lua. Скрипт падал при инициализации (строка 1237).
      Подтверждено логом с реального железа.
    + FIX: ahrs:airspeed_estimate() — обёртка get_as() для совместимости API
      (некоторые версии возвращают (bool,float), другие — float)
    + FIX: gps:horizontal_accuracy() — обёртка get_hacc(), аналогичная проблема
    + FIX: ahrs:get_variances() возвращает 6 значений, не 7 — убран мёртвый код
      EKF offset (переменная off была всегда nil)
    + FIX: gps:num_sats() — добавлен nil-guard (or 0), без него nil<number крашит скрипт
    + FIX: get_likely_flying() fallback срабатывал на земле при TAKEOFF mode
      Guards (elapsed>3с + AS>5) теперь ТОЛЬКО на fallback-пути (INS nil).
    + FIX КРИТИЧЕСКИЙ: мотор не крутился после throw — TECS_PITCH_MAX=15 ставился
      мгновенно при throw, TECS не успевал дать газ. Теперь: throw → 3с spool
      (TECS с полным pitch = мотор раскручивается) → SOFT_CLIMB (ограничения).
      Подтверждено логами 00000004.BIN и 00000005.BIN — C3=1100 весь полёт

  ИЗМЕНЕНИЯ v3.8.2 (SITL-verified tuning):
    + FIX: GPS FIRST WINDOW — 120с вместо 30с, EKF нужно время после DR
      Во время окна: только L1+L2+L6, НЕ меняем gps_ok (return early)
      После окна: ramp L2/L3/L4/L5 за 120с (factor 0→1) + усиленный decay (×5)
    + FIX: Pitot check — пропуск фаз SOFT_CLIMB и CLIMB
    + FIX: EKF TAS innovation — только при GPS (без GPS EKF velocity ненадёжен)
    + FIX: Сброс Pitot буфера при входе в CRUISE
    + TUNE: SP_DECAY 1→3, SP_POS_DEV_RATE 8%→12%, PITOT_ICE_THR 40→80, PITOT_VAR_MIN 0.02→0.005

  ИЗМЕНЕНИЯ v3.8.1 (SITL-verified fixes):
    + FIX(reverted v3.8.3): ahrs:get_yaw() НЕ существует в ArduPlane Lua
      Реальное железо: "attempt to call a nil value (method 'get_yaw_rad')"
      Правильный метод: ahrs:get_yaw() — возвращает yaw в радианах
    + FIX: logger:write labels/format сокращены — ArduPlane ограничение 64 байта на labels
      Убраны избыточные поля: EOff, CusN, WdE, TsV (18 полей → 14 полей)

  ИЗМЕНЕНИЯ v3.8:
    + FIX КРИТИЧЕСКИЙ: мотор не запускался в v3.7
      Причина: pset(TECS_PITCH_MAX=15) + target=100м при броске = TECS не даёт газ.
      TECS видел маленький дефицит энергии при ограниченном pitch → throttle ≈ 0.
      Исправление: при THROW → target=ALT(1000м) БЕЗ ограничений (как v3.5).
      Ограничения pitch/roll применяются ТОЛЬКО при входе в SOFT_CLIMB
      (когда мотор УЖЕ работает и есть минимальная скорость).

  ИЗМЕНЕНИЯ v3.7:
    + ADD: Фаза SOFT_CLIMB — безопасный набор высоты после броска катапульты
      Ограничивает pitch (15°) и roll (10°) до достижения безопасной высоты (100м)
      и скорости (20 м/с). Аналог ArduPilot TKOFF_LVL_PITCH/TKOFF_LVL_ALT.
      Предотвращает сваливание при запуске в GUIDED на 1000м с малой скоростью.
    + FIX: TKOFF параметры ArduPilot не работали (требуют AUTO + NAV_TAKEOFF)
      Lua реализует аналогичную защиту через param:set() в SOFT_CLIMB

  ИЗМЕНЕНИЯ v3.5:
    + FIX КРИТИЧЕСКИЙ: math.atan(y,x) не работает в ArduPlane Lua
      (ошибка "attempt to call a nil value (field 'atan2')")
      Это крашило скрипт после THROW, до setmode(GUIDED) → мотор не запускался
      Добавлена локальная atan2(y,x), заменена во всех: brg(), movept(), update_dr()
    + FIX: Heading fallback в LAUNCH — or w360(S.init_hdg*R2D) = градусы!
      movept() ожидает радианы → неверный WPT. Исправлено: or S.init_hdg
    + FIX: Диагностический таймер LAUNCH — float modulo нестабилен
      Заменено на dedicated launch_diag_ms переменную
    + FIX: DR (0,0) — если launch_valid=false но tgt_valid=true → ERROR+retry
    + ADD: Диагностика mode/target — логирует если set_mode() или
      set_target_location() вернули false

  ИЗМЕНЕНИЯ v3.4:
    + FIX: Порог броска — векторное вычитание гравитации (был скалярный, давал ~2x занижение)
    + FIX: Цикл LAUNCH 50мс вместо 200мс — короткий рывок больше не пропускается
    + ADD: Диагностика — каждые 2с выводит da:X.XX/3.0 (виден реальный уровень рывка)
    + ADD: Предупреждение если ins:get_accel() = nil (INS unavailable)
    + ADD: G-baseline лог при арме — подтверждает что IMU читается

  ИЗМЕНЕНИЯ v3.3:
    + FIX: Мотор не запускался (FBWA без RC) — IMU детекция броска катапульты
    + ADD: LAUNCH_ACC_THR/LAUNCH_ACC_MS — порог и длительность рывка
    + FIX: Убраны pset('TRIM_ARSPD_CM') — параметр не существует в ArduPlane

  ИЗМЕНЕНИЯ v3.2:
    + FIX: GPS deadlock после DR-зоны (динамический L5 порог)
    + FIX: EKF осцилляция (подавление L3 на 10с после switch)
    + FIX: Окно первого доверия GPS (L3+L5 suppressed 30с)
    + FIX: DIVE alt=0 MSL → relative alt (TGT_ALT)
    + FIX: CRUISE без GPS → GUIDED с DR-позицией
    + FIX: Набор высоты без GPS через GUIDED
    + FIX: Pitot as_raw=nil обработка
    + FIX: Валидация координат цели
    + ADD: L6 — детекция постепенного спуфинга (route consistency)

  ИЗМЕНЕНИЯ v3.0:
    + Защита данных: очистка координат старта после взлёта
    + Детекция обмерзания Pitot + автоматический failover
    + Батарея 48 А·ч (6000 мАч ячейки), дальность ~430 км
    + Исправлен рост GPS score (clamp 200)
    + CUSUM автосброс каждые 60с при TRUSTED
    + L2b: проверка высоты GPS vs Baro реализована
    + TERMINAL фаза: 3с подготовки перед DIVE
    + Launch timeout: disarm через 30с
    + Ошибки param:set() логируются
    + Altitude frame: relative_alt для крейсера

  7-СЛОЙНАЯ ЗАЩИТА GPS:
    L1: Сигнальные проверки (спутники, HDOP, HAcc)
    L2: Кинематическая согласованность (IMU vs GPS, Pitot, Baro)
    L3: EKF инновации (variances, offset, NIS)
    L4: Статистика (CUSUM, тренд, скользящее окно)
    L5: Временная согласованность (ветер, курс, DR)
    L6: Консистентность маршрута (постепенный спуфинг)
    L7: Кинематический манёвр (S-поворот — проверка отклика GPS velocity)

  PITOT ICING: детекция замерзания + failover на SYNAIRSPEED
============================================================]]

------------------------------------------------------------
-- КОНФИГУРАЦИЯ МИССИИ
------------------------------------------------------------
local CFG = {
    -- ======= ЦЕЛЬ (ЗАПОЛНИТЬ!) =======
    TGT_LAT         = 0.0,
    TGT_LNG         = 0.0,
    TGT_ALT         = 0,           -- v3.2: высота цели relative (м над стартом), 0 = уровень старта
    LAUNCH_LAT      = 0.0,
    LAUNCH_LNG      = 0.0,

    -- ======= ПОЛЁТ =======
    ALT             = 1000,
    ASPD            = 28,
    MISSION_DIST    = 420000,  -- 420 км (батарея 48А·ч, глубокий разряд ~423 км)
    GPS_MIN_DIST    = 15000,   -- мин. дистанция DR перед включением GPS (15 км)

    -- ======= АНТИСПУФИНГ: пороги L1 (сигнал) =======
    SP_MIN_SATS     = 6,
    SP_MAX_HDOP     = 250,
    SP_HACC_GOOD    = 2.0,
    SP_HACC_BAD     = 10.0,

    -- ======= АНТИСПУФИНГ: пороги L2 (кинематика) =======
    SP_SPD_DEV      = 12,
    SP_ALT_DEV      = 50,
    SP_HDG_DEV      = 25,
    SP_JUMP_SPD     = 80,
    SP_ALT_RATE     = 20,       -- v3: макс. изменение Δ(GPS-Baro) за цикл (м)

    -- ======= АНТИСПУФИНГ: пороги L3 (EKF) =======
    SP_EKF_VEL_THR  = 0.6,
    SP_EKF_POS_THR  = 0.6,
    SP_EKF_OFF_WARN = 10,
    SP_EKF_OFF_CRIT = 50,

    -- ======= АНТИСПУФИНГ: пороги L4 (статистика) =======
    SP_CUSUM_THR    = 3.5,
    SP_CUSUM_DRIFT  = 0.25,
    SP_TREND_WIN    = 30,

    -- ======= АНТИСПУФИНГ: пороги L5 (временнáя) =======
    SP_WIND_RATE    = 3.0,
    SP_POS_DEV      = 300,       -- базовый порог (растёт динамически)
    SP_POS_DEV_RATE = 0.12,      -- v3.8.2: коэфф. роста порога DR (12% от dr_dist, было 8%)
    SP_POS_DEV_MAX  = 15000,     -- v3.2: макс. динамический порог (15 км)

    -- ======= ОБЩЕЕ РЕШЕНИЕ =======
    SP_SCORE_THR    = 50,
    SP_SCORE_MAX    = 200,
    SP_DECAY        = 3,
    SP_RECOVER_MS   = 15000,
    SP_FIRST_GPS_MS = 120000,    -- v3.8.2: окно первого доверия GPS (120с, было 30с — EKF нужно время после DR)

    -- ======= S-ПОВОРОТ ДЛЯ ВЕРИФИКАЦИИ GPS (v3.6) =======
    -- Кинематическая проверка: команда ±OFFSET_DEG, измерение отклика GPS velocity
    -- Если GPS velocity не меняется на манёвр → спуфинг (GPS не видит реального движения)
    STURN_INTERVAL_MS = 120000, -- интервал между проверками (2 минуты)
    STURN_OFFSET_DEG  = 15,     -- угол отклонения курса (°) — малый, не мешает маршруту
    STURN_WAIT_MS     = 4000,   -- ожидание после команды (мс) — самолёт входит в поворот
    STURN_MEAS_MS     = 3000,   -- окно замера GPS-курса (мс)
    STURN_MIN_RESP    = 8,      -- мин. отклик GPS-курса (°) — меньше → score += 25

    -- ======= PITOT ICING (v3) =======
    PITOT_ICE_THR   = 80,       -- v3.8.2: порог обмерзания (было 40, увеличено для устойчивости)
    PITOT_REC_THR   = 10,       -- порог: восстановление
    PITOT_REC_MS    = 10000,    -- время подтверждения восстановления (мс)
    PITOT_MAX_REC   = 2,        -- макс. попыток восстановления
    PITOT_VAR_MIN   = 0.005,    -- v3.8.2: мин. дисперсия AS (было 0.02, SITL ~0.008, реал ~0.1, лёд ~0.001)
    PITOT_BUF_SZ    = 25,       -- буфер: 25 × 200мс = 5с
    PITOT_MISMATCH  = 8,        -- макс. |AS - expected| (м/с)

    -- ======= ТЕРМИНАЛ =======
    TERM_RADIUS     = 3000,
    TERM_SINK_MAX   = 30,
    TERM_PITCH_MIN  = -45,
    TERM_PREP_MS    = 3000,     -- v3: время подготовки TERMINAL (мс)

    -- ======= НАВИГАЦИЯ =======
    WPT_AHEAD       = 5000,
    INS_CORR_ALPHA  = 0.03,
    WIND_ALPHA      = 0.08,

    -- ======= КАТАПУЛЬТА (v3.4) =======
    -- Детекция через вектор: da = |accel - g_baseline|, без геометрической погрешности
    LAUNCH_ACC_THR  = 3.0,    -- м/с² динамического ускорения сверх гравитации (~0.3g)
    LAUNCH_LOOP_MS  = 50,     -- мс — период опроса IMU в фазе LAUNCH (быстрее основного цикла)
    LAUNCH_TIMEOUT  = 300000, -- мс — таймаут ожидания броска (5 минут)

    -- ======= БЕЗОПАСНЫЙ ВЗЛЁТ (v3.7) =======
    -- После броска: консервативный набор высоты до безопасных параметров
    TKOFF_SAFE_ALT  = 100,   -- м — минимальная высота для перехода SOFT_CLIMB → CLIMB
    TKOFF_SAFE_ASPD = 20,    -- м/с — минимальная скорость для перехода
    TKOFF_PITCH_LIM = 15,    -- ° — макс тангаж во время SOFT_CLIMB (ArduPilot: TKOFF_LVL_PITCH)
    TKOFF_ROLL_LIM  = 10,    -- ° — макс крен (прямолинейный набор, без поворотов)

    -- ======= СИСТЕМА =======
    LOOP_MS         = 200,
    LOG_MS          = 2000,
}

------------------------------------------------------------
-- КОНСТАНТЫ
------------------------------------------------------------
local R_EARTH   = 6371000
local D2R       = math.pi / 180.0
local R2D       = 180.0 / math.pi

local MODE_FBWA    = 5
local MODE_CRUISE  = 7
local MODE_GUIDED  = 15

local SEV_EMERG  = 0
local SEV_ALERT  = 1
local SEV_ERR    = 3
local SEV_WARN   = 4
local SEV_NOTICE = 5
local SEV_INFO   = 6

------------------------------------------------------------
-- СОСТОЯНИЕ
------------------------------------------------------------
local S = {
    phase = "INIT",
    init_hdg = 0,
    launch_lat = 0, launch_lng = 0, launch_valid = false,  -- v3: флаг
    tgt_lat = 0, tgt_lng = 0, tgt_valid = false,           -- v3: флаг

    nav_hdg = 0,

    -- Dead Reckoning
    dr_lat = 0, dr_lng = 0, dr_last_ms = 0, dr_dist = 0,

    -- GPS
    gps_ok = false, gps_state = "INIT",
    gps_score = 0,
    gps_first_trust = false,     -- v3.2: первое доверие GPS после DR
    gps_first_trust_ms = 0,      -- v3.2: время начала окна первого доверия
    gps_ramp_ms = 0,             -- v3.8.2: начало ramp L3/L5 после окна
    gps_plat = 0, gps_plng = 0, gps_pms = 0, gps_psats = 0,
    gps_last_fix = 0, gps_good_since = 0,
    ekf_src = 0,

    -- Ветер
    wn = 0, we = 0, w_ok = false,
    wn_prev = 0, we_prev = 0, wind_upd_ms = 0,

    -- EKF мониторинг
    ekf_vel_var = 0, ekf_pos_var = 0, ekf_hgt_var = 0,
    ekf_offset_ne = 0, ekf_offset_d = 0, ekf_tas_var = 0,
    ekf_switch_ms = 0,             -- v3.2: время последнего переключения EKF source

    -- CUSUM
    cusum_pos = 0, cusum_neg = 0,
    cusum_spd_pos = 0, cusum_spd_neg = 0,
    cusum_reset_ms = 0,         -- v3: время последнего авторесета

    -- Тренд
    trend_buf = {}, trend_idx = 0,

    -- GPS velocity
    gps_pvel_n = 0, gps_pvel_e = 0, gps_pvel_ms = 0,

    -- L2b: высота (v3)
    alt_diff_prev = nil,        -- предыдущая разница GPS-Baro

    -- Pitot icing (v3)
    pitot_iced = false,
    pitot_score = 0,
    pitot_good_ms = 0,
    pitot_ice_count = 0,
    as_buf = {}, as_idx = 0,
    as_var = 0, as_mean = 0,

    -- Защита от разворота
    min_d2t = 999999,

    -- v3.2: Детекция постепенного спуфинга (route consistency)
    rc_gps_d2t_prev = 0,          -- предыдущее d2t по GPS
    rc_diverge_cnt = 0,           -- счётчик циклов удаления от цели по GPS
    rc_check_ms = 0,              -- время последней проверки

    -- Безопасность (v3)
    sec_wiped = false,

    -- Флаги
    cur_mode = -1, log_ms = 0,
    ew_flag = false, spoof_flag = false,
    launch_ms = 0, term_params = false, term_ms = 0,

    -- Катапульта (v3.4/v3.5)
    launch_thrown   = false,  -- бросок был обнаружен через IMU
    throw_ms        = 0,      -- v3.8.3: timestamp обнаружения броска
    launch_g_x      = 0,      -- базовый вектор гравитации при арме (X)
    launch_g_y      = 0,      -- базовый вектор гравитации при арме (Y)
    launch_g_z      = 0,      -- базовый вектор гравитации при арме (Z)
    launch_diag_ms  = 0,      -- v3.5: таймер диагностических сообщений LAUNCH

    -- Безопасный взлёт (v3.7)
    soft_climb_ms    = 0,     -- время начала SOFT_CLIMB
    pitch_max_saved  = 20,    -- сохранённый TECS_PITCH_MAX
    roll_lim_saved   = 45,    -- сохранённый ROLL_LIMIT_DEG

    -- S-поворот GPS верификация (v3.6)
    sturn_phase     = 0,      -- 0=idle, 1=turning (ждём оседания), 2=measuring
    sturn_ms        = 0,      -- время начала текущей фазы
    sturn_hdg_ref   = 0,      -- GPS-курс до манёвра (°), для сравнения
    sturn_dir       = -1,     -- направление (±1), чередуем R/L
    sturn_offset    = 0.0,    -- текущее смещение курса (рад), apply в navigate()
    sturn_next_ms   = 0,      -- время следующей проверки
}

------------------------------------------------------------
-- УТИЛИТЫ
------------------------------------------------------------
local function lg(s, m) gcs:send_text(s, "[WN3] " .. m) end
local function ms() return millis():tofloat() end

local function w360(a) a = a % 360; if a < 0 then a = a + 360 end; return a end
local function w180(a) a = w360(a); if a > 180 then a = a - 360 end; return a end

-- v3.5: math.atan(y,x) с 2 аргументами НЕ работает в ArduPlane Lua
-- (ошибка "attempt to call a nil value (field 'atan2')")
-- Используем собственную реализацию atan2
local function atan2(y, x)
    if x > 0 then return math.atan(y / x)
    elseif x < 0 then
        return math.atan(y / x) + (y >= 0 and math.pi or -math.pi)
    elseif y > 0 then return math.pi * 0.5
    elseif y < 0 then return -math.pi * 0.5
    else return 0.0 end
end

-- v3.8.3: совместимые обёртки API (некоторые версии ArduPlane возвращают (bool,val))
local function get_as()
    local a, b = ahrs:airspeed_estimate()
    if type(a) == "number" then return a end
    if a then return b end
    return nil
end
local function get_hacc()
    local a, b = gps:horizontal_accuracy(0)
    if type(a) == "number" then return a end
    if a then return b end
    return nil
end

local function hdist(a1,o1,a2,o2)
    local dl=(a2-a1)*D2R; local dn=(o2-o1)*D2R
    local a=math.sin(dl*0.5)^2+math.cos(a1*D2R)*math.cos(a2*D2R)*math.sin(dn*0.5)^2
    return 2*R_EARTH*math.asin(math.min(1.0, math.sqrt(a)))  -- v3: clamp для безопасности
end

local function brg(a1,o1,a2,o2)
    local r1,r2=a1*D2R,a2*D2R; local dl=(o2-o1)*D2R
    return atan2(math.sin(dl)*math.cos(r2),
        math.cos(r1)*math.sin(r2)-math.sin(r1)*math.cos(r2)*math.cos(dl))
end

local function movept(la,lo,b,d)
    local a=la*D2R; local o=lo*D2R; local r=d/R_EARTH
    local a2=math.asin(math.sin(a)*math.cos(r)+math.cos(a)*math.sin(r)*math.cos(b))
    local o2=o+atan2(math.sin(b)*math.sin(r)*math.cos(a),math.cos(r)-math.sin(a)*math.sin(a2))
    return a2*R2D, o2*R2D
end

local function mkloc(la, lo, alt, relative)
    local l = Location()
    l:lat(math.floor(la * 1e7 + 0.5))
    l:lng(math.floor(lo * 1e7 + 0.5))
    l:alt(math.floor(alt * 100 + 0.5))
    if relative then
        pcall(function() l:relative_alt(true) end)
    end
    return l
end

local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end

local function pset(name, val)
    if not param:set(name, val) then
        lg(SEV_ERR, "PARAM FAIL: " .. name)
    end
end

------------------------------------------------------------
-- БЕЗОПАСНОСТЬ: очистка данных старта (v3)
------------------------------------------------------------
local function wipe_launch_data()
    if S.sec_wiped then return end
    S.launch_lat = 0; S.launch_lng = 0; S.launch_valid = false
    CFG.LAUNCH_LAT = 0; CFG.LAUNCH_LNG = 0
    CFG.TGT_LAT = 0; CFG.TGT_LNG = 0
    S.sec_wiped = true
    lg(SEV_NOTICE, "SEC: COORDS WIPED")
end

------------------------------------------------------------
-- DEAD RECKONING
------------------------------------------------------------
local function update_dr()
    local t = ms()
    if S.dr_last_ms == 0 then S.dr_last_ms = t; return end
    local dt = (t - S.dr_last_ms) / 1000; S.dr_last_ms = t
    if dt <= 0 or dt > 2 then return end
    local h = ahrs:get_yaw(); if not h then return end

    local as
    if S.pitot_iced then
        -- v3: при обмерзании Pitot — GPS GS или фиксированная скорость
        if S.gps_ok then
            as = gps:ground_speed(0) or CFG.ASPD
        else
            as = CFG.ASPD
        end
    else
        as = get_as()
        if not as or as < 1 then as = CFG.ASPD end
    end

    local vn = as * math.cos(h); local ve = as * math.sin(h)
    if S.w_ok then vn = vn + S.wn; ve = ve + S.we end
    local gs = math.sqrt(vn * vn + ve * ve); local c = atan2(ve, vn)
    local step = gs * dt
    S.dr_lat, S.dr_lng = movept(S.dr_lat, S.dr_lng, c, step)
    S.dr_dist = S.dr_dist + step
end

------------------------------------------------------------
-- ОЦЕНКА ВЕТРА
------------------------------------------------------------
local function update_wind()
    if not S.gps_ok then return end
    if S.pitot_iced then return end  -- v3: ветер ненадёжен при замёрзшем Pitot
    local gs = gps:ground_speed(0); if not gs or gs < 5 then return end
    local gc = gps:ground_course(0); if not gc then return end; gc = gc * D2R
    local h = ahrs:get_yaw(); local as = get_as()
    if not h or not as or as < 1 then return end
    local gn = gs * math.cos(gc); local ge = gs * math.sin(gc)
    local an = as * math.cos(h); local ae = as * math.sin(h)
    local a = CFG.WIND_ALPHA
    S.wn = S.wn * (1 - a) + (gn - an) * a
    S.we = S.we * (1 - a) + (ge - ae) * a
    S.w_ok = true
end

------------------------------------------------------------
-- ДЕТЕКЦИЯ ОБМЕРЗАНИЯ PITOT (v3)
------------------------------------------------------------
local function check_pitot()
    if S.phase == "INIT" or S.phase == "WAIT_ARM" or S.phase == "LAUNCH" or S.phase == "SOFT_CLIMB" or S.phase == "CLIMB" then return end

    local t = ms()
    local score = 0

    -- 1. Текущая скорость
    local as_raw = get_as()
    local gs = gps:ground_speed(0)

    -- v3.2: as_raw=nil означает Pitot полностью мёртв (крышка не снята или обрыв)
    if as_raw == nil then
        score = score + 50
    end

    -- 2. Буфер дисперсии AS
    if as_raw and as_raw > 0 then
        S.as_idx = S.as_idx + 1
        if S.as_idx > CFG.PITOT_BUF_SZ then S.as_idx = 1 end
        S.as_buf[S.as_idx] = as_raw
    end

    -- 3. Полное обмерзание: AS → 0, GS нормальная
    if as_raw and gs and gs > 15 and as_raw < 5 then
        score = score + 50
    end

    -- 4. Замёрзший датчик: дисперсия → 0
    if #S.as_buf >= CFG.PITOT_BUF_SZ then
        local sum, sum2 = 0, 0
        for i = 1, CFG.PITOT_BUF_SZ do
            sum = sum + S.as_buf[i]
            sum2 = sum2 + S.as_buf[i] ^ 2
        end
        S.as_mean = sum / CFG.PITOT_BUF_SZ
        S.as_var = sum2 / CFG.PITOT_BUF_SZ - S.as_mean ^ 2
        if S.as_var < 0 then S.as_var = 0 end  -- float safety

        if S.as_var < CFG.PITOT_VAR_MIN and S.as_mean > 5 then
            score = score + 30
        end
    end

    -- 5. EKF TAS innovation (v3.8.2: только при GPS — без GPS EKF velocity ненадёжен)
    if S.gps_ok then
        local ok, vv, pv, hv, mv, tv = ahrs:get_variances()
        if ok and tv then
            S.ekf_tas_var = tv
            if tv > 0.5 then score = score + 25 end
            if tv > 1.0 then score = score + 15 end
        end
    end

    -- 6. Несовпадение AS vs GPS+ветер (только при живом GPS и ветре)
    if not S.pitot_iced and S.gps_ok and S.w_ok and as_raw and gs then
        local hdg = ahrs:get_yaw()
        if hdg then
            local hw = S.wn * math.cos(hdg) + S.we * math.sin(hdg)
            local expected = gs - hw
            if math.abs(as_raw - expected) > CFG.PITOT_MISMATCH then
                score = score + 20
            end
        end
    end

    -- Затухание + накопление + clamp
    S.pitot_score = math.max(0, S.pitot_score - 2) + score
    S.pitot_score = math.min(S.pitot_score, 200)

    -- Решение
    if not S.pitot_iced then
        if S.pitot_score > CFG.PITOT_ICE_THR then
            S.pitot_iced = true
            S.pitot_ice_count = S.pitot_ice_count + 1
            S.pitot_good_ms = 0
            pset('ARSPD_USE', 0)
            pset('TECS_SYNAIRSPEED', 1)
            lg(SEV_ALERT, "PITOT ICE! #" .. S.pitot_ice_count ..
                " sc:" .. math.floor(S.pitot_score) ..
                " var:" .. string.format("%.3f", S.as_var))
        end
    else
        -- Восстановление
        if S.pitot_ice_count > CFG.PITOT_MAX_REC then
            return  -- навсегда отключён
        end

        if S.pitot_score < CFG.PITOT_REC_THR then
            if S.pitot_good_ms == 0 then S.pitot_good_ms = t end
            if (t - S.pitot_good_ms) > CFG.PITOT_REC_MS then
                S.pitot_iced = false
                S.pitot_good_ms = 0
                pset('ARSPD_USE', 1)
                pset('TECS_SYNAIRSPEED', 0)
                lg(SEV_NOTICE, "PITOT OK! ARSPD_USE=1")
            end
        else
            S.pitot_good_ms = 0
        end
    end
end

------------------------------------------------------------
-- 5-СЛОЙНЫЙ АНТИСПУФИНГ
------------------------------------------------------------

-- СЛОЙ 1: Сигнальные проверки
local function layer1_signal()
    local score = 0
    local sats = gps:num_sats(0) or 0
    if sats < CFG.SP_MIN_SATS then score = score + 15 end
    if S.gps_psats > 0 and (S.gps_psats - sats) > 3 then
        score = score + 20
    end
    S.gps_psats = sats

    local hdop = gps:get_hdop(0)
    if hdop and hdop > CFG.SP_MAX_HDOP then score = score + 10 end

    local hacc = get_hacc()
    if hacc then
        if hacc < CFG.SP_HACC_GOOD and S.ekf_pos_var > 0.8 then
            score = score + 25
        end
        if hacc > CFG.SP_HACC_BAD then
            score = score + 10
        end
    end

    return score
end

-- СЛОЙ 2: Кинематическая согласованность
local function layer2_kinematics()
    local score = 0
    local t = ms()

    -- 2a: Скорость GPS vs Pitot (ПРОПУСК при обмерзании Pitot)
    if not S.pitot_iced then
        local gs = gps:ground_speed(0)
        local as = get_as()
        if gs and as and as > 5 then
            local expected_gs = as
            if S.w_ok then
                local wh = ahrs:get_yaw()
                if wh then
                    local wcomp = S.wn * math.cos(wh) + S.we * math.sin(wh)
                    expected_gs = as + wcomp
                end
            end
            local diff = math.abs(gs - expected_gs)
            if diff > CFG.SP_SPD_DEV then score = score + 15 end
        end
    end

    -- 2b: Высота GPS vs Baro (v3: реализовано)
    local gloc = gps:location(0)
    local balt = baro:get_altitude()
    if gloc and balt then
        local galt = gloc:alt() / 100.0
        local alt_diff = galt - balt
        if S.alt_diff_prev then
            local change = math.abs(alt_diff - S.alt_diff_prev)
            if change > CFG.SP_ALT_RATE then
                score = score + 15  -- разница GPS-Baro резко изменилась
            end
        end
        S.alt_diff_prev = alt_diff
    end

    -- 2c: Скачок позиции GPS
    local gloc2 = gps:location(0)
    if gloc2 and S.gps_plat ~= 0 and S.gps_pms > 0 then
        local glat = gloc2:lat() / 1e7
        local glng = gloc2:lng() / 1e7
        local jump = hdist(glat, glng, S.gps_plat, S.gps_plng)
        local dt = (t - S.gps_pms) / 1000
        if dt > 0 and dt < 5 then
            local jspd = jump / dt
            if jspd > CFG.SP_JUMP_SPD then
                score = score + 30
            end
        end
    end

    -- 2d: Курс GPS vs AHRS
    local gs2 = gps:ground_speed(0)
    local gc = gps:ground_course(0)
    local hd = ahrs:get_yaw()
    if gc and hd and gs2 and gs2 > 10 then
        local diff = math.abs(w180(gc - w360(hd * R2D)))
        if diff > CFG.SP_HDG_DEV then score = score + 20 end
    end

    -- 2e: GPS ускорение vs физика
    local gvel = gps:velocity(0)
    if gvel and S.gps_pvel_ms > 0 then
        local dt = (t - S.gps_pvel_ms) / 1000
        if dt > 0.05 and dt < 2 then
            local an = (gvel:x() - S.gps_pvel_n) / dt
            local ae = (gvel:y() - S.gps_pvel_e) / dt
            local acc = math.sqrt(an * an + ae * ae)
            if acc > 8 then score = score + 20 end
            if acc > 15 then score = score + 15 end
        end
    end
    if gvel then
        S.gps_pvel_n = gvel:x(); S.gps_pvel_e = gvel:y(); S.gps_pvel_ms = t
    end

    return score
end

-- СЛОЙ 3: EKF инновации
local function layer3_ekf()
    local score = 0
    -- v3.2: подавляем L3 на 10с после переключения EKF source (варансы нестабильны)
    if S.ekf_switch_ms > 0 and (ms() - S.ekf_switch_ms) < 10000 then
        return 0
    end
    local ok, vv, pv, hv, mv, tv = ahrs:get_variances()
    if not ok then return 0 end

    S.ekf_vel_var = vv
    S.ekf_pos_var = pv
    S.ekf_hgt_var = hv

    if vv > CFG.SP_EKF_VEL_THR then score = score + 10 end
    if pv > CFG.SP_EKF_POS_THR then score = score + 10 end
    if vv > 1.0 then score = score + 15 end
    if pv > 1.0 then score = score + 15 end

    -- v3.8.3: убран блок EKF offset (off) — get_variances() возвращает 6 значений,
    -- 7-я переменная off была всегда nil (dead code). mv = магнитная дисперсия (Vector3f)

    local ekf_vel = ahrs:get_velocity_NED()
    local gps_vel = gps:velocity(0)
    if ekf_vel and gps_vel then
        local dn = ekf_vel:x() - gps_vel:x()
        local de = ekf_vel:y() - gps_vel:y()
        local vdiff = math.sqrt(dn * dn + de * de)
        if vdiff > 2.0 then score = score + 10 end
        if vdiff > 5.0 then score = score + 15 end
    end

    if not ahrs:healthy() then score = score + 20 end

    return score
end

-- СЛОЙ 4: Статистика (CUSUM)
local function layer4_statistics()
    local score = 0

    local gloc = gps:location(0)
    if gloc and S.dr_dist > 2000 then
        local glat = gloc:lat() / 1e7
        local glng = gloc:lng() / 1e7
        local dev = hdist(glat, glng, S.dr_lat, S.dr_lng)
        local expected_err = math.max(50, S.dr_dist * 0.035)
        local residual = dev / expected_err

        local drift = CFG.SP_CUSUM_DRIFT
        S.cusum_pos = math.max(0, S.cusum_pos + (residual - 1.0 - drift))
        S.cusum_neg = math.max(0, S.cusum_neg + (-residual + 1.0 - drift))

        if S.cusum_pos > CFG.SP_CUSUM_THR then score = score + 25 end
        if S.cusum_neg > CFG.SP_CUSUM_THR then score = score + 25 end

        S.trend_idx = S.trend_idx + 1
        if S.trend_idx > CFG.SP_TREND_WIN then S.trend_idx = 1 end
        S.trend_buf[S.trend_idx] = dev

        if #S.trend_buf >= CFG.SP_TREND_WIN then
            local half = math.floor(CFG.SP_TREND_WIN / 2)
            local avg1, avg2 = 0, 0
            for i = 1, half do
                local idx = ((S.trend_idx - CFG.SP_TREND_WIN + i - 1) % CFG.SP_TREND_WIN) + 1
                avg1 = avg1 + (S.trend_buf[idx] or 0)
            end
            for i = half + 1, CFG.SP_TREND_WIN do
                local idx = ((S.trend_idx - CFG.SP_TREND_WIN + i - 1) % CFG.SP_TREND_WIN) + 1
                avg2 = avg2 + (S.trend_buf[idx] or 0)
            end
            avg1 = avg1 / half
            avg2 = avg2 / (CFG.SP_TREND_WIN - half)
            if avg2 - avg1 > 50 then score = score + 15 end
        end
    end

    -- CUSUM на скорости: ПРОПУСК при обмерзании Pitot (v3)
    if not S.pitot_iced then
        local gs = gps:ground_speed(0)
        local as = get_as()
        if gs and as and as > 5 then
            local ratio = gs / as
            S.cusum_spd_pos = math.max(0, S.cusum_spd_pos + (ratio - 1.3))
            S.cusum_spd_neg = math.max(0, S.cusum_spd_neg + (0.7 - ratio))
            if S.cusum_spd_pos > 10 or S.cusum_spd_neg > 10 then
                score = score + 15
            end
        end
    end

    return score
end

-- СЛОЙ 5: Временнáя согласованность
local function layer5_temporal()
    local score = 0
    local t = ms()

    if S.w_ok and S.wind_upd_ms > 0 then
        local dt = (t - S.wind_upd_ms) / 1000
        if dt > 5 and dt < 30 then
            local dw = math.sqrt(
                (math.abs(S.wn - S.wn_prev) / (dt / 10)) ^ 2 +
                (math.abs(S.we - S.we_prev) / (dt / 10)) ^ 2
            )
            if dw > CFG.SP_WIND_RATE then score = score + 15 end
        end
    end
    if S.w_ok and (t - S.wind_upd_ms) > 10000 then
        S.wn_prev = S.wn; S.we_prev = S.we; S.wind_upd_ms = t
    end

    local gloc = gps:location(0)
    if gloc and S.dr_dist > 2000 then
        local glat = gloc:lat() / 1e7; local glng = gloc:lng() / 1e7
        local dev = hdist(glat, glng, S.dr_lat, S.dr_lng)
        -- v3.2: динамический порог — растёт с DR дистанцией (без ветра DR дрейфует)
        local dyn_dev = math.min(
            CFG.SP_POS_DEV_MAX,
            math.max(CFG.SP_POS_DEV, S.dr_dist * CFG.SP_POS_DEV_RATE)
        )
        if dev > dyn_dev then score = score + 20 end
    end

    if S.gps_last_fix > 0 and (t - S.gps_last_fix) > 5000 then
        if not S.ew_flag then
            lg(SEV_WARN, "EW: GPS LOST >" .. math.floor((t - S.gps_last_fix) / 1000) .. "s")
            S.ew_flag = true
        end
    end

    return score
end

-- v3.2: СЛОЙ 6: Консистентность маршрута (детекция постепенного спуфинга)
-- При TRUSTED GPS проверяем: d2t по GPS должно уменьшаться.
-- Если GPS показывает удаление от цели > 60с — спуфинг.
local function layer6_route_consistency()
    local score = 0
    if not S.gps_ok or not S.tgt_valid then return 0 end

    local gloc = gps:location(0)
    if not gloc then return 0 end
    local glat = gloc:lat() / 1e7; local glng = gloc:lng() / 1e7
    local gps_d2t = hdist(glat, glng, S.tgt_lat, S.tgt_lng)

    local t = ms()
    -- Проверяем каждые 10 секунд
    if S.rc_check_ms > 0 and (t - S.rc_check_ms) < 10000 then return 0 end
    S.rc_check_ms = t

    if S.rc_gps_d2t_prev > 0 then
        -- Если d2t по GPS выросло (удаляемся от цели)
        if gps_d2t > S.rc_gps_d2t_prev + 100 then  -- +100м допуск на ветер
            S.rc_diverge_cnt = S.rc_diverge_cnt + 1
        else
            S.rc_diverge_cnt = math.max(0, S.rc_diverge_cnt - 1)
        end

        -- 6 раз подряд (60с) удаляемся — подозрительно
        if S.rc_diverge_cnt > 6 then
            score = score + 25
            lg(SEV_WARN, "L6: ROUTE DIVERGE cnt:" .. S.rc_diverge_cnt)
        end
    end
    S.rc_gps_d2t_prev = gps_d2t

    return score
end

-- v3.6: СЛОЙ 7 (кинематический манёвр): S-поворот для верификации GPS
-- Командуем ±STURN_OFFSET_DEG отклонение курса через GUIDED.
-- Реальный самолёт физически повернёт → GPS velocity должна показать изменение курса.
-- Если GPS velocity не отвечает → GPS spoofed (статическая или pre-recorded позиция).
-- Вызов: из главного цикла (check_sturn_gps) + sturn_offset применяется в navigate().
local function check_sturn_gps()
    local t = ms()

    -- Только в CRUISE при доверенном GPS
    if S.phase ~= "CRUISE" or not S.gps_ok then
        if S.sturn_phase ~= 0 then
            S.sturn_offset = 0.0
            S.sturn_phase  = 0
        end
        return
    end

    -- Инициализация: первый S-поворот через STURN_INTERVAL_MS после входа в CRUISE
    if S.sturn_next_ms == 0 then
        S.sturn_next_ms = t + CFG.STURN_INTERVAL_MS
        return
    end

    -- PHASE 0 (IDLE): ждём плановое время
    if S.sturn_phase == 0 then
        if t < S.sturn_next_ms then return end

        -- Измеряем текущий GPS-курс по velocity (NED: x=N, y=E)
        local gv = gps:velocity(0)
        if not gv then S.sturn_next_ms = t + 5000; return end
        local gsp = math.sqrt(gv:x()^2 + gv:y()^2)
        if gsp < 5 then S.sturn_next_ms = t + 5000; return end  -- слишком медленно

        S.sturn_hdg_ref = w360(atan2(gv:y(), gv:x()) * R2D)
        S.sturn_dir     = -S.sturn_dir    -- чередуем R (+1) / L (-1)
        S.sturn_offset  = S.sturn_dir * CFG.STURN_OFFSET_DEG * D2R
        S.sturn_ms      = t
        S.sturn_phase   = 1
        lg(SEV_INFO, "STURN:" .. (S.sturn_dir > 0 and "R" or "L") ..
            math.floor(CFG.STURN_OFFSET_DEG) .. " ref:" .. math.floor(S.sturn_hdg_ref))
        return
    end

    -- PHASE 1 (TURNING): ждём STURN_WAIT_MS — самолёт входит в поворот
    if S.sturn_phase == 1 then
        if (t - S.sturn_ms) >= CFG.STURN_WAIT_MS then
            S.sturn_phase = 2
            S.sturn_ms    = t  -- сброс для фазы замера
        end
        return
    end

    -- PHASE 2 (MEASURING): ждём STURN_MEAS_MS, потом замер GPS velocity
    if S.sturn_phase == 2 then
        if (t - S.sturn_ms) < CFG.STURN_MEAS_MS then return end

        local gv = gps:velocity(0)
        if gv then
            local gsp = math.sqrt(gv:x()^2 + gv:y()^2)
            if gsp >= 5 then
                local gc_now = w360(atan2(gv:y(), gv:x()) * R2D)
                local chg    = w180(gc_now - S.sturn_hdg_ref)
                -- Ожидаем: при sturn_dir=+1 (R) → chg > 0; при -1 (L) → chg < 0
                local responded = (S.sturn_dir > 0 and chg >= CFG.STURN_MIN_RESP) or
                                  (S.sturn_dir < 0 and chg <= -CFG.STURN_MIN_RESP)
                if not responded then
                    -- GPS не показал поворот → подозрительно
                    S.gps_score = math.min(S.gps_score + 25, CFG.SP_SCORE_MAX)
                    lg(SEV_WARN, "STURN: NO RESP exp" ..
                        (S.sturn_dir > 0 and "+" or "") .. math.floor(CFG.STURN_OFFSET_DEG) ..
                        " got:" .. string.format("%.1f", chg) .. " sc:" .. math.floor(S.gps_score))
                else
                    lg(SEV_INFO, "STURN: OK " .. string.format("%+.1f", chg) .. "deg")
                end
            end
        end

        -- Возврат к нормальному курсу
        S.sturn_offset  = 0.0
        S.sturn_phase   = 0
        S.sturn_next_ms = t + CFG.STURN_INTERVAL_MS
        return
    end
end

------------------------------------------------------------
-- ГЛАВНАЯ ФУНКЦИЯ АНТИСПУФИНГА
------------------------------------------------------------
local function check_gps()
    local t = ms()
    local fix = gps:status(0)
    if fix >= 3 then
        S.gps_last_fix = t
        S.ew_flag = false
    end

    if fix < 3 then
        S.gps_ok = false
        S.gps_good_since = 0
        S.gps_state = "REJECTED"
        return
    end

    local s1 = layer1_signal()
    local s2 = layer2_kinematics()
    local s3 = layer3_ekf()
    local s4 = layer4_statistics()
    local s5 = layer5_temporal()
    local s6 = layer6_route_consistency()  -- v3.2

    local raw = s1 + s2 + s3 + s4 + s5 + s6

    -- v3.8.2: ПЕРВОЕ ОКНО GPS после DR-зоны
    -- Во время окна: только L1+L2+L6, НЕ меняем gps_ok (EKF остаётся на INS)
    -- После окна: ramp L3/L4/L5 за 120с + усиленный decay
    if not S.gps_first_trust then
        if S.gps_first_trust_ms == 0 then
            S.gps_first_trust_ms = t
            S.gps_score = 0
            lg(SEV_NOTICE, "GPS FIRST WINDOW: L3+L4+L5 suppressed " ..
                math.floor(CFG.SP_FIRST_GPS_MS/1000) .. "s")
        end
        if (t - S.gps_first_trust_ms) < CFG.SP_FIRST_GPS_MS then
            raw = s1 + s2 + s6
            S.cusum_pos = 0; S.cusum_neg = 0
            -- v3.8.2: только считаем score, НЕ меняем gps_ok/gps_state
            local decay_w = CFG.SP_DECAY
            if raw <= 5 then decay_w = CFG.SP_DECAY * 5 end
            S.gps_score = math.max(0, S.gps_score - decay_w) + raw
            S.gps_score = math.min(S.gps_score, CFG.SP_SCORE_MAX)
            return  -- НЕ оцениваем состояние во время окна
        else
            S.gps_first_trust = true
            S.gps_ramp_ms = t
            S.gps_score = 0  -- v3.8.2: сброс score на выходе из окна
            lg(SEV_NOTICE, "GPS FIRST WINDOW CLOSED > ramp 120s")
        end
    end

    -- v3.8.2: ramp L3/L4/L5 за 120с + усиленный decay во время ramp
    local in_ramp = false
    if S.gps_first_trust and S.gps_ramp_ms and S.gps_ramp_ms > 0 then
        local ramp_elapsed = t - S.gps_ramp_ms
        if ramp_elapsed < 120000 then
            local f = ramp_elapsed / 120000  -- 0.0 → 1.0 за 120с
            raw = s1 + math.floor(s2 * f) + math.floor(s3 * f) + math.floor(s4 * f) + math.floor(s5 * f) + s6
            in_ramp = true
        else
            S.gps_ramp_ms = 0
        end
    end

    -- v3.8.2: decay — усиленный при ramp или при чистом GPS
    local decay = CFG.SP_DECAY
    if in_ramp then
        decay = CFG.SP_DECAY * 5  -- усиленный decay во время ramp
    elseif raw <= 5 then
        decay = CFG.SP_DECAY * 5
    end
    S.gps_score = math.max(0, S.gps_score - decay) + raw
    S.gps_score = math.min(S.gps_score, CFG.SP_SCORE_MAX)

    local was_ok = S.gps_ok

    if S.gps_score < CFG.SP_SCORE_THR * 0.5 then
        if not S.gps_ok then
            if S.gps_good_since == 0 then S.gps_good_since = t end
            if (t - S.gps_good_since) >= CFG.SP_RECOVER_MS then
                S.gps_ok = true
                S.gps_state = "TRUSTED"
                S.spoof_flag = false
                S.cusum_pos = 0; S.cusum_neg = 0
                S.cusum_spd_pos = 0; S.cusum_spd_neg = 0
                lg(SEV_NOTICE, "GPS TRUSTED sc:" .. math.floor(S.gps_score))
            else
                S.gps_state = "RECOVERY"
            end
        else
            S.gps_state = "TRUSTED"
        end
    elseif S.gps_score < CFG.SP_SCORE_THR then
        S.gps_state = "SUSPICIOUS"
        S.gps_good_since = 0
    else
        S.gps_ok = false
        S.gps_good_since = 0
        S.gps_state = "REJECTED"
        if was_ok then
            S.spoof_flag = true
            lg(SEV_ALERT, "GPS REJECTED! sc:" .. math.floor(S.gps_score) ..
                " L1:" .. s1 .. " L2:" .. s2 .. " L3:" .. s3 ..
                " L4:" .. s4 .. " L5:" .. s5 .. " L6:" .. s6)
        end
    end

    -- v3: периодический сброс CUSUM при TRUSTED (предотвращает ложные срабатывания)
    if S.gps_ok and S.gps_state == "TRUSTED" then
        if S.cusum_reset_ms == 0 then S.cusum_reset_ms = t end
        if (t - S.cusum_reset_ms) > 60000 then
            S.cusum_pos = S.cusum_pos * 0.5
            S.cusum_neg = S.cusum_neg * 0.5
            S.cusum_spd_pos = S.cusum_spd_pos * 0.5
            S.cusum_spd_neg = S.cusum_spd_neg * 0.5
            S.cusum_reset_ms = t
        end
    else
        S.cusum_reset_ms = 0
    end

    -- Сохраняем GPS
    local gloc = gps:location(0)
    if gloc then
        S.gps_plat = gloc:lat() / 1e7
        S.gps_plng = gloc:lng() / 1e7
        S.gps_pms = t
    end

    -- Коррекция DR по GPS (только при TRUSTED)
    if S.gps_ok and S.dr_dist > 500 and gloc then
        local glat = gloc:lat() / 1e7; local glng = gloc:lng() / 1e7
        local a = CFG.INS_CORR_ALPHA
        S.dr_lat = S.dr_lat + (glat - S.dr_lat) * a
        S.dr_lng = S.dr_lng + (glng - S.dr_lng) * a
    end
end

------------------------------------------------------------
-- EKF SOURCE
------------------------------------------------------------
local function set_ekf_src(use_gps)
    local tgt = use_gps and 0 or 1
    if tgt ~= S.ekf_src then
        local ok, err = pcall(function() ahrs:set_posvelyaw_source_set(tgt) end)
        if ok then
            S.ekf_src = tgt
            S.ekf_switch_ms = ms()  -- v3.2: запоминаем время переключения
            lg(SEV_NOTICE, "EKF>" .. (use_gps and "GPS" or "INS"))
        else
            lg(SEV_ERR, "EKF SWITCH FAIL: " .. tostring(err))
        end
    end
end

------------------------------------------------------------
-- РЕЖИМ
------------------------------------------------------------
local function setmode(m)
    if S.cur_mode ~= m then
        if vehicle:set_mode(m) then
            S.cur_mode = m
        else
            lg(SEV_ERR, "MODE FAIL:" .. m)  -- v3.5: диагностика отказа режима
        end
    end
end

------------------------------------------------------------
-- ТЕРМИНАЛ
------------------------------------------------------------
local function setup_terminal()
    if S.term_params then return end
    pset('TECS_SINK_MAX', CFG.TERM_SINK_MAX)
    pset('TECS_PITCH_MIN', CFG.TERM_PITCH_MIN)
    pset('PTCH_LIM_MIN_DEG', CFG.TERM_PITCH_MIN)
    lg(SEV_ALERT, "DIVE PARAMS SET")
    S.term_params = true
end

------------------------------------------------------------
-- НАВИГАЦИЯ
------------------------------------------------------------
local function navigate()
    if S.phase == "INIT" or S.phase == "WAIT_ARM" or S.phase == "LAUNCH" or S.phase == "SOFT_CLIMB" then return end

    if not S.tgt_valid then return end  -- v3: проверка

    local d2t = hdist(S.dr_lat, S.dr_lng, S.tgt_lat, S.tgt_lng)
    local b2t = brg(S.dr_lat, S.dr_lng, S.tgt_lat, S.tgt_lng)
    S.nav_hdg = b2t

    -- Обновить мин. дистанцию до цели
    if d2t < S.min_d2t then S.min_d2t = d2t end

    -- Защита от разворота: если цель позади и удаляемся
    local hdg_diff = math.abs(w180((b2t - S.init_hdg) * R2D))
    if hdg_diff > 90 and d2t > S.min_d2t + 500 then
        if S.phase ~= "TERMINAL" and S.phase ~= "DIVE" then
            S.phase = "TERMINAL"
            S.term_ms = ms()
            setup_terminal()
            wipe_launch_data()
            lg(SEV_ALERT, "OVERSHOOT > TERMINAL D:" .. math.floor(d2t))
        end
    end

    -- Вход в TERMINAL
    if d2t < CFG.TERM_RADIUS and S.phase ~= "TERMINAL" and S.phase ~= "DIVE" then
        S.phase = "TERMINAL"
        S.term_ms = ms()
        setup_terminal()
        wipe_launch_data()  -- v3: очистка перед завершением
        lg(SEV_ALERT, "*** TERMINAL *** D=" .. math.floor(d2t))
    end

    -- v3: TERMINAL фаза — подготовка 3 секунды
    if S.phase == "TERMINAL" then
        set_ekf_src(S.gps_ok)
        setmode(MODE_GUIDED)
        -- Направляемся к цели на текущей высоте
        if S.gps_ok then
            vehicle:set_target_location(mkloc(S.tgt_lat, S.tgt_lng, CFG.ALT, true))
        else
            local pl, po = movept(S.dr_lat, S.dr_lng, b2t, math.min(d2t, CFG.WPT_AHEAD))
            vehicle:set_target_location(mkloc(pl, po, CFG.ALT, true))
        end
        if (ms() - S.term_ms) > CFG.TERM_PREP_MS then
            S.phase = "DIVE"
            lg(SEV_ALERT, "*** DIVE ***")
        end
        return
    end

    -- DIVE
    if S.phase == "DIVE" then
        set_ekf_src(S.gps_ok)
        setmode(MODE_GUIDED)
        -- v3.2: relative alt вместо MSL — TGT_ALT задаёт высоту цели над стартом
        if S.gps_ok then
            vehicle:set_target_location(mkloc(S.tgt_lat, S.tgt_lng, CFG.TGT_ALT, true))
        else
            local pl, po = movept(S.dr_lat, S.dr_lng, b2t, math.min(d2t, CFG.WPT_AHEAD))
            vehicle:set_target_location(mkloc(pl, po, CFG.TGT_ALT, true))
        end
        return
    end

    -- CLIMB
    if S.phase == "CLIMB" then
        local alt = baro:get_altitude()
        if alt and alt >= CFG.ALT * 0.95 then
            S.phase = "CRUISE"
            wipe_launch_data()  -- v3: очистка после набора высоты
            S.as_buf = {}; S.as_idx = 0; S.pitot_score = 0  -- v3.8.2: сброс Pitot буфера при CRUISE
            lg(SEV_INFO, "CRUISE H=" .. math.floor(alt))
        end
    end

    -- CRUISE / CLIMB
    if S.gps_ok then
        set_ekf_src(true)
        update_wind()
        setmode(MODE_GUIDED)
        -- v3.6: S-turn offset для кинематической верификации GPS
        local nav_hdg_off = b2t + S.sturn_offset
        local wl, wo = movept(S.dr_lat, S.dr_lng, nav_hdg_off, CFG.WPT_AHEAD)
        vehicle:set_target_location(mkloc(wl, wo, CFG.ALT, true))
    else
        set_ekf_src(false)
        -- v3.2: GUIDED с DR-позицией вместо неуправляемого CRUISE
        -- CRUISE без RC не позволяет управлять курсом → снос ветром
        setmode(MODE_GUIDED)
        local wl, wo = movept(S.dr_lat, S.dr_lng, b2t, CFG.WPT_AHEAD)
        vehicle:set_target_location(mkloc(wl, wo, CFG.ALT, true))
    end
end

------------------------------------------------------------
-- ЛОГ
------------------------------------------------------------
local function do_log()
    local t = ms()
    if (t - S.log_ms) < CFG.LOG_MS then return end
    S.log_ms = t

    local alt = baro:get_altitude() or 0
    local as = get_as() or 0
    local hd = ahrs:get_yaw()
    local hdeg = hd and w360(hd * R2D) or 0
    local d2t = 0
    if S.tgt_valid then
        d2t = hdist(S.dr_lat, S.dr_lng, S.tgt_lat, S.tgt_lng)
    end

    -- v3: не логируем координаты, только дистанции
    lg(SEV_INFO, string.format(
        "%s H:%d V:%.0f C:%.0f D:%.0fk R:%.0fk G:%s[%s] S:%d P:%s",
        S.phase, math.floor(alt), as, hdeg,
        S.dr_dist / 1000, d2t / 1000,
        S.gps_ok and "Y" or "N", S.gps_state,
        math.floor(S.gps_score),
        S.pitot_iced and "ICE" or "OK"
    ))

    logger:write('WNV3',
        'Alt,As,Hd,Ds,DT,GO,Sc,EV,EP,CP,WN,PI,PS,AV',
        'ffffffffffffff',
        alt, as, hdeg, S.dr_dist, d2t,
        S.gps_ok and 1.0 or 0.0, S.gps_score,
        S.ekf_vel_var, S.ekf_pos_var,
        S.cusum_pos, S.wn,
        S.pitot_iced and 1.0 or 0.0, S.pitot_score,
        S.as_var
    )
end

------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ
------------------------------------------------------------
local function update()

    -- INIT
    if S.phase == "INIT" then
        local h = ahrs:get_yaw()
        if not h then lg(SEV_INFO, "AHRS..."); return update, 1000 end
        S.init_hdg = h; S.nav_hdg = h
        lg(SEV_NOTICE, "HDG:" .. math.floor(w360(h * R2D)))

        if gps:status(0) >= 3 then
            local loc = gps:location(0)
            if loc then
                S.launch_lat = loc:lat() / 1e7; S.launch_lng = loc:lng() / 1e7
                S.launch_valid = true
                -- v3: НЕ логируем координаты старта в GCS
                lg(SEV_NOTICE, "GPS FIX OK")
            end
        end
        if not S.launch_valid and CFG.LAUNCH_LAT ~= 0 then
            S.launch_lat = CFG.LAUNCH_LAT; S.launch_lng = CFG.LAUNCH_LNG
            S.launch_valid = true
            lg(SEV_WARN, "START: CONFIG")
        end

        -- v3.2: валидация координат цели
        if CFG.TGT_LAT ~= 0 then
            if math.abs(CFG.TGT_LAT) > 90 or math.abs(CFG.TGT_LNG) > 180 then
                lg(SEV_ERR, "BAD TGT COORDS! lat:" .. CFG.TGT_LAT .. " lng:" .. CFG.TGT_LNG)
                return update, 5000
            end
            S.tgt_lat = CFG.TGT_LAT; S.tgt_lng = CFG.TGT_LNG
            S.tgt_valid = true
            -- Проверка дистанции (подсказка оператору)
            if S.launch_valid then
                local chk_d = hdist(S.launch_lat, S.launch_lng, S.tgt_lat, S.tgt_lng)
                lg(SEV_NOTICE, "DIST:" .. math.floor(chk_d / 1000) .. "km")
                if chk_d < 1000 then
                    lg(SEV_WARN, "TGT < 1km! CHECK COORDS")
                end
                if chk_d > 500000 then
                    lg(SEV_WARN, "TGT > 500km! CHECK BATT")
                end
            end
        elseif S.launch_valid then
            S.tgt_lat, S.tgt_lng = movept(S.launch_lat, S.launch_lng, S.init_hdg, CFG.MISSION_DIST)
            S.tgt_valid = true
            lg(SEV_NOTICE, "TGT: AZIMUTH")
        end

        if not S.tgt_valid then
            lg(SEV_ERR, "NO TARGET! CHECK CFG")
            return update, 5000
        end

        -- v3.5: FIX — если нет позиции старта, DR будет от (0,0) — это недопустимо
        if not S.launch_valid then
            lg(SEV_ERR, "NO LAUNCH POS! Need GPS fix or CFG.LAUNCH_LAT")
            return update, 5000
        end

        S.dr_lat = S.launch_lat; S.dr_lng = S.launch_lng
        S.wind_upd_ms = ms()
        S.phase = "WAIT_ARM"
        lg(SEV_NOTICE, "=== WAIT ARM ===")
        return update, CFG.LOOP_MS
    end

    -- WAIT_ARM
    if S.phase == "WAIT_ARM" then
        if arming:is_armed() then
            local h = ahrs:get_yaw()
            if h then S.init_hdg = h; S.nav_hdg = h end
            lg(SEV_ALERT, "ARMED! HDG:" .. math.floor(w360(S.init_hdg * R2D)))
            set_ekf_src(false)
            -- Сохраняем вектор гравитации при арме (любой наклон борта учитывается)
            local a0 = ins:get_accel(0)
            if a0 then
                S.launch_g_x, S.launch_g_y, S.launch_g_z = a0:x(), a0:y(), a0:z()
                lg(SEV_NOTICE, "G-baseline: " .. string.format("%.2f", math.sqrt(a0:x()^2+a0:y()^2+a0:z()^2)) .. "m/s2")
            else
                S.launch_g_x, S.launch_g_y, S.launch_g_z = 0, 0, 9.81
                lg(SEV_WARN, "INS unavailable — using default g-baseline")
            end
            setmode(MODE_FBWA)  -- мотор выключен (нет RC) — ждём рывок катапульты
            S.launch_thrown = false
            S.phase = "LAUNCH"; S.launch_ms = ms()
        end
        return update, CFG.LOOP_MS
    end

    -- LAUNCH
    if S.phase == "LAUNCH" then
        -- v3.4: векторная детекция броска — da = |accel - g_baseline|
        -- Убирает геометрическую погрешность при горизонтальном броске.
        -- Быстрый цикл 50мс: не пропускаем короткие рывки.
        if not S.launch_thrown then
            local accel = ins:get_accel(0)
            if accel then
                local da = math.sqrt(
                    (accel:x()-S.launch_g_x)^2 +
                    (accel:y()-S.launch_g_y)^2 +
                    (accel:z()-S.launch_g_z)^2
                )
                -- Диагностика: каждые 2с выводим текущее da (для настройки порога)
                -- v3.5: используем dedicated таймер (float modulo нестабилен)
                if (ms() - S.launch_diag_ms) >= 2000 then
                    S.launch_diag_ms = ms()
                    lg(SEV_INFO, "LAUNCH da:" .. string.format("%.2f", da) .. "/" .. CFG.LAUNCH_ACC_THR)
                end
                if da > CFG.LAUNCH_ACC_THR then
                    S.launch_thrown = true
                    S.throw_ms = ms()
                    lg(SEV_ALERT, "THROW! da=" .. string.format("%.1f", da) .. "m/s2 > MOTOR ON")
                    -- v3.8: НЕ ограничиваем TECS при броске!
                    -- Сохраняем штатные лимиты для последующего SOFT_CLIMB
                    S.pitch_max_saved = param:get('TECS_PITCH_MAX') or 20
                    S.roll_lim_saved  = param:get('ROLL_LIMIT_DEG') or 45
                    -- v3.8: target = CFG.ALT (1000м) — TECS получает большой дефицит → полный газ
                    local hdg = S.tgt_valid
                        and brg(S.dr_lat, S.dr_lng, S.tgt_lat, S.tgt_lng)
                        or  S.init_hdg
                    local wl, wo = movept(S.dr_lat, S.dr_lng, hdg, CFG.WPT_AHEAD)
                    setmode(MODE_GUIDED)
                    if not vehicle:set_target_location(mkloc(wl, wo, CFG.ALT, true)) then
                        lg(SEV_WARN, "THROW: TGT FAIL — check DR pos")
                    end
                end
            else
                -- ins:get_accel() недоступен — детектируем только через get_likely_flying()
                if (ms() - S.launch_diag_ms) >= 2000 then
                    S.launch_diag_ms = ms()
                    lg(SEV_WARN, "LAUNCH: INS nil — waiting get_likely_flying()")
                end
            end
        end

        -- v3.8.3: Два пути в SOFT_CLIMB:
        --   Путь 1: IMU throw → ждём 3с (TECS раскручивает мотор без ограничений) → SOFT_CLIMB
        --   Путь 2: INS nil fallback — get_likely_flying() с guards (elapsed>3s, AS>5)
        --     Guards отсекают ложный TAKEOFF mode который ставит likely_flying=true при арме
        if S.launch_thrown and (ms() - S.throw_ms) > 3000 then
            -- Путь 1: мотор крутится 3с с полным pitch → теперь ограничиваем
            pset('TECS_PITCH_MAX', CFG.TKOFF_PITCH_LIM)
            pset('ROLL_LIMIT_DEG', CFG.TKOFF_ROLL_LIM)
            S.phase = "SOFT_CLIMB"; S.soft_climb_ms = ms(); S.dr_last_ms = ms()
            lg(SEV_ALERT, "LAUNCHED > SOFT_CLIMB (pitch<=" ..
                CFG.TKOFF_PITCH_LIM .. " roll<=" .. CFG.TKOFF_ROLL_LIM .. ")")
            setmode(MODE_GUIDED)
        elseif S.launch_thrown then
            -- Мотор раскручивается — ждём 3с, диагностика
            if (ms() - S.launch_diag_ms) >= 1000 then
                S.launch_diag_ms = ms()
                local t_left = math.floor((3000 - (ms() - S.throw_ms)) / 1000)
                lg(SEV_INFO, "THROW: motor spool " .. t_left .. "s")
            end
        elseif vehicle:get_likely_flying()
           and (ms() - S.launch_ms) > 3000
           and get_as() and get_as() > 5
        then
            -- Путь 2: fallback — INS nil, но борт реально летит
            S.pitch_max_saved = param:get('TECS_PITCH_MAX') or 20
            S.roll_lim_saved  = param:get('ROLL_LIMIT_DEG') or 45
            S.launch_thrown = true
            S.throw_ms = ms()
            lg(SEV_WARN, "FLYING w/o throw detect — GUIDED + full ALT target")
            setmode(MODE_GUIDED)
            local hdg = S.tgt_valid
                and brg(S.dr_lat, S.dr_lng, S.tgt_lat, S.tgt_lng)
                or S.init_hdg
            local wl, wo = movept(S.dr_lat, S.dr_lng, hdg, CFG.WPT_AHEAD)
            vehicle:set_target_location(mkloc(wl, wo, CFG.ALT, true))
            -- НЕ ставим pitch/roll limits сразу — ждём 3с spool (следующая итерация)
        elseif (ms() - S.launch_ms) > CFG.LAUNCH_TIMEOUT then
            lg(SEV_ERR, "LAUNCH TIMEOUT — DISARM")
            arming:disarm()
            S.launch_thrown = false
            S.phase = "WAIT_ARM"
        end
        return update, CFG.LAUNCH_LOOP_MS  -- 50мс вместо 200мс
    end

    -- SOFT_CLIMB (v3.7): безопасный набор высоты после броска
    -- Ограниченный pitch/roll, прямолинейный набор до безопасных параметров
    if S.phase == "SOFT_CLIMB" then
        update_dr()
        local alt = baro:get_altitude()
        local as = get_as()

        -- v3.8: target = ALT (1000м) — TECS даёт газ для набора
        -- Ограничения pitch/roll уже установлены при входе в SOFT_CLIMB
        setmode(MODE_GUIDED)
        local hdg = S.tgt_valid
            and brg(S.dr_lat, S.dr_lng, S.tgt_lat, S.tgt_lng)
            or S.init_hdg
        local wl, wo = movept(S.dr_lat, S.dr_lng, hdg, CFG.WPT_AHEAD)
        vehicle:set_target_location(mkloc(wl, wo, CFG.ALT, true))

        -- Диагностика каждые 2с
        if (ms() - S.launch_diag_ms) >= 2000 then
            S.launch_diag_ms = ms()
            lg(SEV_INFO, "SOFT_CLIMB H:" .. math.floor(alt or 0) ..
                "/" .. CFG.TKOFF_SAFE_ALT ..
                " V:" .. math.floor(as or 0) ..
                "/" .. CFG.TKOFF_SAFE_ASPD)
        end

        -- Переход в CLIMB при достижении безопасных параметров
        if alt and alt >= CFG.TKOFF_SAFE_ALT * 0.9
           and as and as >= CFG.TKOFF_SAFE_ASPD then
            -- Восстанавливаем штатные лимиты
            pset('TECS_PITCH_MAX', S.pitch_max_saved)
            pset('ROLL_LIMIT_DEG', S.roll_lim_saved)
            S.phase = "CLIMB"
            lg(SEV_ALERT, "SOFT_CLIMB OK H:" .. math.floor(alt) ..
                " V:" .. math.floor(as) .. " > CLIMB " .. CFG.ALT .. "m")
        end

        -- Мягкий таймаут: 60с + скорость >= 80% порога — переходить
        if (ms() - S.soft_climb_ms) > 60000 and as and as >= CFG.TKOFF_SAFE_ASPD * 0.8 then
            pset('TECS_PITCH_MAX', S.pitch_max_saved)
            pset('ROLL_LIMIT_DEG', S.roll_lim_saved)
            S.phase = "CLIMB"
            lg(SEV_WARN, "SOFT_CLIMB TIMEOUT > CLIMB H:" .. math.floor(alt or 0))
        end

        -- Абсолютный таймаут: 90с — восстановить лимиты в любом случае
        -- Защита от зависания при отказе Pitot (as=nil блокирует мягкий таймаут)
        if (ms() - S.soft_climb_ms) > 90000 then
            pset('TECS_PITCH_MAX', S.pitch_max_saved)
            pset('ROLL_LIMIT_DEG', S.roll_lim_saved)
            S.phase = "CLIMB"
            lg(SEV_ERR, "SOFT_CLIMB HARD TIMEOUT 90s > CLIMB H:" .. math.floor(alt or 0))
        end

        do_log()
        return update, CFG.LOOP_MS
    end

    -- === ОСНОВНОЙ ЦИКЛ ===
    update_dr()
    check_pitot()   -- v3: детекция обмерзания Pitot
    if S.dr_dist >= CFG.GPS_MIN_DIST then
        check_gps()
        check_sturn_gps()  -- v3.6: S-turn кинематическая верификация GPS
    end
    navigate()
    do_log()

    return update, CFG.LOOP_MS
end

------------------------------------------------------------
-- СТАРТ
------------------------------------------------------------
lg(SEV_NOTICE, "===========================")
lg(SEV_NOTICE, "  WING NAV v3.8.3 7L+PITOT+THROW+SAFETKO")
lg(SEV_NOTICE, "  Alt:" .. CFG.ALT .. " Spd:" .. math.floor(CFG.ASPD))
lg(SEV_NOTICE, "  Dist:" .. math.floor(CFG.MISSION_DIST / 1000) .. "km")
lg(SEV_NOTICE, "===========================")

return update, 2000
