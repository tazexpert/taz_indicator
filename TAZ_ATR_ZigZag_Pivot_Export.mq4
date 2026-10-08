//+------------------------------------------------------------------+
//|                               TAZ_ATR_ZigZag_Pivot_Export.mq4    |
//|   Export จุดกลับตัวแบบ ATR ZigZag จากข้อมูล M1 ออกเป็น CSV       |
//|   สำหรับนำไปใช้ backtest (รันครั้งเดียวแล้วจบ)                    |
//+------------------------------------------------------------------+
#property copyright "TAZ"
#property version   "1.00"
#property strict
#property script_show_inputs

//====================================================================
// Input parameters
//====================================================================
input datetime InpStartDate              = D'2026.01.01 00:00'; // วันเริ่มต้นของข้อมูลที่จะ export
input datetime InpEndDate                = 0;                   // วันสิ้นสุด (0 = ถึงแท่งล่าสุดที่ปิดแล้ว)
input int      InpMaxBars                = 300000;              // จำนวนแท่ง M1 สูงสุดที่ประมวลผล
input int      InpATRPeriod              = 14;                  // คาบ ATR
input double   InpATRMultiplier          = 2.0;                 // ตัวคูณ ATR สำหรับเกณฑ์กลับตัว
input int      InpEMA1                   = 21;                  // EMA เส้นที่ 1 (Close)
input int      InpEMA2                   = 50;                  // EMA เส้นที่ 2 (Close)
input int      InpEMA3                   = 100;                 // EMA เส้นที่ 3 (Close)
input int      InpMACDFast               = 12;                  // MACD Fast EMA (Close)
input int      InpMACDSlow               = 26;                  // MACD Slow EMA (Close)
input int      InpMACDSignal             = 9;                   // MACD Signal (Close)
input bool     InpExportConfirmBarValues = true;                // export ค่า indicator ณ แท่งยืนยันด้วยหรือไม่
input string   InpFilePrefix             = "";                  // คำนำหน้าชื่อไฟล์ (ไม่บังคับ)

//====================================================================
// ค่าคงที่
//====================================================================
#define WARMUP_BARS     1000   // จำนวนแท่งขั้นต่ำก่อน InpStartDate สำหรับ warm-up indicator
#define PROGRESS_STEP   10000  // แสดงความคืบหน้าทุก ๆ กี่แท่ง
#define DIR_UNKNOWN     0      // ยังไม่ทราบทิศทาง
#define DIR_UP          1      // กำลังขึ้น (หาจุดยอด)
#define DIR_DOWN        -1     // กำลังลง (หาจุดต่ำ)
#define PIVOT_HIGH      1      // ชนิดจุดกลับตัว: ยอด
#define PIVOT_LOW       -1     // ชนิดจุดกลับตัว: ต่ำ

//====================================================================
// ข้อมูล M1 ที่คัดลอกมา (index 0 = แท่งเก่าสุด → n-1 = แท่งใหม่สุด)
//====================================================================
datetime g_time[];
double   g_open[];
double   g_high[];
double   g_low[];
double   g_close[];
long     g_vol[];
double   g_atr[];

//====================================================================
// ผลลัพธ์จุดกลับตัว
//====================================================================
int g_pvIdx[];    // index ของแท่ง pivot
int g_pvType[];   // PIVOT_HIGH / PIVOT_LOW
int g_pvConf[];   // index ของแท่งยืนยัน
int g_pvCount = 0;

//+------------------------------------------------------------------+
//| ตรวจว่าค่า ATR ใช้งานได้หรือไม่ (ต้อง > 0 และไม่ใช่ EMPTY_VALUE)  |
//+------------------------------------------------------------------+
bool IsValidAtr(const double v)
  {
   return(v > 0.0 && v < EMPTY_VALUE);
  }

//+------------------------------------------------------------------+
//| จัดรูปแบบราคา / EMA                                             |
//+------------------------------------------------------------------+
string FmtPrice(const double v)
  {
   return(DoubleToString(v, _Digits));
  }

//+------------------------------------------------------------------+
//| จัดรูปแบบ ATR / swing_size / MACD (ทศนิยม _Digits + 2)            |
//+------------------------------------------------------------------+
string FmtExt(const double v)
  {
   return(DoubleToString(v, _Digits + 2));
  }

//+------------------------------------------------------------------+
//| จัดรูปแบบเวลา yyyy.mm.dd hh:mi                                   |
//+------------------------------------------------------------------+
string FmtTime(const datetime t)
  {
   return(TimeToString(t, TIME_DATE | TIME_MINUTES));
  }

//+------------------------------------------------------------------+
//| จัดรูปแบบวันที่ yyyymmdd สำหรับชื่อไฟล์                          |
//+------------------------------------------------------------------+
string FmtYmd(const datetime t)
  {
   return(StringFormat("%04d%02d%02d", TimeYear(t), TimeMonth(t), TimeDay(t)));
  }

//+------------------------------------------------------------------+
//| จัดรูปแบบตัวคูณ ATR สำหรับชื่อไฟล์ เช่น 2.0, 2.5, 1.75           |
//+------------------------------------------------------------------+
string FmtMultiplier(const double v)
  {
   string s   = DoubleToString(v, 2);
   int    dot = StringFind(s, ".");
   // ตัดเลข 0 ท้ายออก แต่คงทศนิยมไว้อย่างน้อย 1 ตำแหน่ง
   while(dot >= 0 && StringLen(s) - dot > 2 && StringGetCharacter(s, StringLen(s) - 1) == '0')
      s = StringSubstr(s, 0, StringLen(s) - 1);
   return(s);
  }

//+------------------------------------------------------------------+
//| แทนที่อักขระที่ใช้ในชื่อไฟล์ไม่ได้ด้วย "_"                        |
//+------------------------------------------------------------------+
string SanitizeFileName(string s)
  {
   StringReplace(s, "\\", "_");
   StringReplace(s, "/", "_");
   StringReplace(s, ":", "_");
   StringReplace(s, "*", "_");
   StringReplace(s, "?", "_");
   StringReplace(s, "\"", "_");
   StringReplace(s, "<", "_");
   StringReplace(s, ">", "_");
   StringReplace(s, "|", "_");
   return(s);
  }

//+------------------------------------------------------------------+
//| แจ้งเตือนกรณี history ไม่พอ พร้อมคำแนะนำ                           |
//+------------------------------------------------------------------+
void AlertHistory(const string sym, const string reason)
  {
   int      bars   = iBars(sym, PERIOD_M1);
   datetime oldest = (bars > 0) ? iTime(sym, PERIOD_M1, bars - 1) : 0;
   string msg = "ATR ZigZag Export: " + reason +
                " | แท่ง M1 เก่าสุดที่มี = " + FmtTime(oldest) +
                " | จำนวนแท่ง M1 ที่มี = " + IntegerToString(bars) +
                " | ต้องการข้อมูลตั้งแต่ " + FmtTime(InpStartDate) +
                " และแท่ง warm-up ก่อนหน้าอย่างน้อย " + IntegerToString(WARMUP_BARS) + " แท่ง" +
                " | วิธีแก้: เพิ่ม \"Max bars in history\" และ \"Max bars in chart\" ใน Tools > Options > Charts" +
                " แล้วดาวน์โหลด history M1 ใน History Center (F2) จากนั้นรัน script ใหม่";
   Print(msg);
   Alert(msg);
  }

//+------------------------------------------------------------------+
//| รอให้ terminal โหลด history M1 (กรณี error 4066)                  |
//+------------------------------------------------------------------+
bool WaitForHistory(const string sym)
  {
   for(int i = 0; i < 20; i++)
     {
      ResetLastError();
      datetime t   = iTime(sym, PERIOD_M1, 1);
      int      err = GetLastError();
      if(t > 0 && err != ERR_HISTORY_WILL_UPDATED && iBars(sym, PERIOD_M1) > 1)
         return(true);
      Comment("ATR ZigZag Export: กำลังรอโหลด history M1 ... (" + IntegerToString(i + 1) + ")");
      Sleep(500);
      if(IsStopped())
         return(false);
     }
   return(iBars(sym, PERIOD_M1) > 1);
  }

//+------------------------------------------------------------------+
//| คัดลอกข้อมูล M1 จาก startShift (เก่า) ถึง endShift (ใหม่)         |
//| คืนค่า 1 = สำเร็จ, 0 = ผู้ใช้หยุด, -1 = มีแท่งใหม่เกิดระหว่างคัดลอก |
//+------------------------------------------------------------------+
int LoadData(const string sym, const int startShift, const int endShift)
  {
   int n = startShift - endShift + 1;
   ArrayResize(g_time,  n);
   ArrayResize(g_open,  n);
   ArrayResize(g_high,  n);
   ArrayResize(g_low,   n);
   ArrayResize(g_close, n);
   ArrayResize(g_vol,   n);
   ArrayResize(g_atr,   n);

   datetime anchorStart = iTime(sym, PERIOD_M1, startShift);
   datetime anchorEnd   = iTime(sym, PERIOD_M1, endShift);

   for(int k = 0; k < n; k++)
     {
      int shift = startShift - k;   // k = 0 คือแท่งเก่าสุด
      g_time[k]  = iTime(sym,   PERIOD_M1, shift);
      g_open[k]  = iOpen(sym,   PERIOD_M1, shift);
      g_high[k]  = iHigh(sym,   PERIOD_M1, shift);
      g_low[k]   = iLow(sym,    PERIOD_M1, shift);
      g_close[k] = iClose(sym,  PERIOD_M1, shift);
      g_vol[k]   = iVolume(sym, PERIOD_M1, shift);
      g_atr[k]   = iATR(sym,    PERIOD_M1, InpATRPeriod, shift);

      // เวลาต้องเพิ่มขึ้นเสมอ ถ้าไม่ใช่แปลว่า shift เลื่อนเพราะมีแท่งใหม่เกิดขึ้น
      if(k > 0 && g_time[k] <= g_time[k - 1])
         return(-1);

      if(k % PROGRESS_STEP == 0)
        {
         Comment(StringFormat("ATR ZigZag Export: กำลังโหลดข้อมูล M1 %d / %d", k, n));
         if(IsStopped())
            return(0);
        }
     }

   // ตรวจซ้ำว่า shift ไม่เลื่อนระหว่างคัดลอก
   if(iTime(sym, PERIOD_M1, startShift) != anchorStart || iTime(sym, PERIOD_M1, endShift) != anchorEnd)
      return(-1);
   return(1);
  }

//+------------------------------------------------------------------+
//| เพิ่มจุดกลับตัวที่ยืนยันแล้ว                                      |
//+------------------------------------------------------------------+
void AddPivot(const int idx, const int type, const int confIdx)
  {
   // แท่งยืนยันต้องอยู่หลังแท่ง pivot เสมอ และ HIGH/LOW ต้องสลับกัน
   if(confIdx <= idx)
      return;
   if(g_pvCount > 0 && g_pvType[g_pvCount - 1] == type)
      return;

   ArrayResize(g_pvIdx,  g_pvCount + 1, 1000);
   ArrayResize(g_pvType, g_pvCount + 1, 1000);
   ArrayResize(g_pvConf, g_pvCount + 1, 1000);
   g_pvIdx[g_pvCount]  = idx;
   g_pvType[g_pvCount] = type;
   g_pvConf[g_pvCount] = confIdx;
   g_pvCount++;
  }

//+------------------------------------------------------------------+
//| คำนวณ ATR ZigZag (oldest → newest)                               |
//| คืนค่า จำนวนแท่งที่ถูกข้ามเพราะ ATR ใช้ไม่ได้ หรือ -1 ถ้าผู้ใช้หยุด |
//+------------------------------------------------------------------+
int ComputeZigZag(const int n)
  {
   g_pvCount = 0;
   int skipped = 0;
   int dir     = DIR_UNKNOWN;

   // สถานะช่วง UNKNOWN: High สูงสุด และ Low ต่ำสุดตั้งแต่แท่งแรก
   bool   haveInit = false;
   double hiP = 0.0, hiA = 0.0;
   double loP = 0.0, loA = 0.0;
   int    hiI = -1,  loI = -1;

   // สถานะ candidate ในทิศทาง UP / DOWN
   double candP = 0.0, candA = 0.0;
   int    candI = -1;

   for(int k = 0; k < n; k++)
     {
      if(k % PROGRESS_STEP == 0)
        {
         Comment(StringFormat("ATR ZigZag Export: กำลังคำนวณ ZigZag %d / %d (พบ %d จุด)", k, n, g_pvCount));
         if(IsStopped())
            return(-1);
        }

      // ATR เป็น 0 หรือคำนวณไม่ได้ → ข้ามแท่งนี้
      if(!IsValidAtr(g_atr[k]))
        {
         skipped++;
         continue;
        }

      double h = g_high[k];
      double l = g_low[k];

      //--- 3.1 ช่วงเริ่มต้น (ยังไม่ทราบทิศทาง)
      if(dir == DIR_UNKNOWN)
        {
         if(!haveInit)
           {
            hiP = h; hiI = k; hiA = g_atr[k];
            loP = l; loI = k; loA = g_atr[k];
            haveInit = true;
            continue;
           }

         // อัปเดต High สูงสุด / Low ต่ำสุด
         if(h > hiP) { hiP = h; hiI = k; hiA = g_atr[k]; }
         if(l < loP) { loP = l; loI = k; loA = g_atr[k]; }

         // ตรวจการกลับตัว (แท่ง extreme ต้องเก่ากว่าแท่งปัจจุบัน)
         bool downFromHi = (hiI < k) && (hiP - l >= InpATRMultiplier * hiA);
         bool upFromLo   = (loI < k) && (h - loP >= InpATRMultiplier * loA);

         // เกิดทั้งสองอย่างในแท่งเดียวกัน → เลือกจุดที่เกิดก่อน
         if(downFromHi && upFromLo)
           {
            if(hiI < loI)
               upFromLo = false;
            else if(loI < hiI)
               downFromHi = false;
            else
              {
               // กรณีพิเศษ: High และ Low อยู่แท่งเดียวกัน → เลือกฝั่งที่เคลื่อนที่ได้มากกว่า (เทียบกับ threshold)
               if((hiP - l) / hiA >= (h - loP) / loA)
                  upFromLo = false;
               else
                  downFromHi = false;
              }
           }

         if(downFromHi)
           {
            AddPivot(hiI, PIVOT_HIGH, k);
            dir = DIR_DOWN;
            candP = l; candI = k; candA = g_atr[k];
           }
         else if(upFromLo)
           {
            AddPivot(loI, PIVOT_LOW, k);
            dir = DIR_UP;
            candP = h; candI = k; candA = g_atr[k];
           }
         continue;
        }

      //--- 3.2 ทิศทาง UP (กำลังหาจุดยอด)
      if(dir == DIR_UP)
        {
         if(h > candP)
           {
            // ทำ High ใหม่ → อัปเดต candidate และไม่ตรวจการกลับตัวในแท่งนี้
            candP = h; candI = k; candA = g_atr[k];
            continue;
           }
         if(candI < k && candP - l >= InpATRMultiplier * candA)
           {
            // ยืนยันจุด HIGH; แท่งปัจจุบันคือแท่งยืนยัน
            AddPivot(candI, PIVOT_HIGH, k);
            dir = DIR_DOWN;
            candP = l; candI = k; candA = g_atr[k];
           }
         continue;
        }

      //--- 3.3 ทิศทาง DOWN (กำลังหาจุดต่ำ)
      if(l < candP)
        {
         // ทำ Low ใหม่ → อัปเดต candidate และไม่ตรวจการกลับตัวในแท่งนี้
         candP = l; candI = k; candA = g_atr[k];
         continue;
        }
      if(candI < k && h - candP >= InpATRMultiplier * candA)
        {
         // ยืนยันจุด LOW; แท่งปัจจุบันคือแท่งยืนยัน
         AddPivot(candI, PIVOT_LOW, k);
         dir = DIR_UP;
         candP = h; candI = k; candA = g_atr[k];
        }
     }
   // candidate สุดท้ายที่ยังไม่ถูกยืนยัน จะไม่ถูกบันทึก (ไม่ export)
   return(skipped);
  }

//+------------------------------------------------------------------+
//| สร้างข้อความค่า EMA/MACD ณ เวลาแท่งที่กำหนด (คั่นด้วย comma)       |
//| ใช้ iBarShift แบบ exact เพื่อให้ถูกต้องแม้มีแท่งใหม่เกิดระหว่างรัน  |
//+------------------------------------------------------------------+
string IndicatorFields(const string sym, const datetime t)
  {
   int shift = iBarShift(sym, PERIOD_M1, t, true);
   if(shift < 1)
      return(",,,,,");   // หาแท่งไม่เจอ → เว้นว่าง 6 ช่อง

   double ema1   = iMA(sym, PERIOD_M1, InpEMA1, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema2   = iMA(sym, PERIOD_M1, InpEMA2, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema3   = iMA(sym, PERIOD_M1, InpEMA3, 0, MODE_EMA, PRICE_CLOSE, shift);
   double macdM  = iMACD(sym, PERIOD_M1, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE, MODE_MAIN,   shift);
   double macdS  = iMACD(sym, PERIOD_M1, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE, MODE_SIGNAL, shift);

   return(FmtPrice(ema1) + "," + FmtPrice(ema2) + "," + FmtPrice(ema3) + "," +
          FmtExt(macdM) + "," + FmtExt(macdS) + "," + FmtExt(macdM - macdS));
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   uint   startTick = GetTickCount();
   string sym       = Symbol();

   //=================================================================
   // 1) ตรวจสอบ input
   //=================================================================
   if(InpATRPeriod <= 0 || InpATRMultiplier <= 0.0 || InpMaxBars <= 0 ||
      InpEMA1 <= 0 || InpEMA2 <= 0 || InpEMA3 <= 0 ||
      InpMACDFast <= 0 || InpMACDSlow <= 0 || InpMACDSignal <= 0 || InpMACDFast >= InpMACDSlow)
     {
      Alert("ATR ZigZag Export: ค่า input ไม่ถูกต้อง (คาบต้อง > 0, ตัวคูณ ATR > 0 และ MACD Fast < Slow)");
      return;
     }
   if(InpEndDate != 0 && InpEndDate <= InpStartDate)
     {
      Alert("ATR ZigZag Export: InpEndDate ต้องมากกว่า InpStartDate (หรือใส่ 0 = ถึงแท่งล่าสุด)");
      return;
     }

   //=================================================================
   // 2) เตรียมข้อมูลและตรวจสอบ history M1
   //=================================================================
   if(!WaitForHistory(sym))
     {
      Comment("");
      AlertHistory(sym, "ไม่สามารถโหลด history M1 ได้");
      return;
     }

   int      totalBars   = iBars(sym, PERIOD_M1);
   int      oldestShift = totalBars - 1;
   datetime oldestTime  = iTime(sym, PERIOD_M1, oldestShift);

   // แท่งเก่าสุดที่มีอยู่ใหม่กว่าวันเริ่มต้น → history ไม่พอ
   if(oldestTime > InpStartDate)
     {
      Comment("");
      AlertHistory(sym, "history M1 ไม่ครอบคลุมวันเริ่มต้น");
      return;
     }

   // หา shift เริ่มต้น = แท่งแรกที่เวลา >= InpStartDate
   int startShift = iBarShift(sym, PERIOD_M1, InpStartDate, false);
   if(startShift < 0)
     {
      Comment("");
      AlertHistory(sym, "หาแท่งเริ่มต้นไม่พบ (iBarShift error " + IntegerToString(GetLastError()) + ")");
      return;
     }
   while(startShift > 1 && iTime(sym, PERIOD_M1, startShift) < InpStartDate)
      startShift--;

   // หา shift สุดท้าย (ไม่ใช้แท่ง 0 ที่ยังไม่ปิด)
   int endShift = 1;
   if(InpEndDate != 0)
     {
      endShift = iBarShift(sym, PERIOD_M1, InpEndDate, false);
      if(endShift < 1)
         endShift = 1;
     }
   if(endShift > startShift || iTime(sym, PERIOD_M1, startShift) < InpStartDate)
     {
      Comment("");
      Alert("ATR ZigZag Export: ไม่มีแท่ง M1 ที่ปิดแล้วในช่วงวันที่ที่กำหนด");
      return;
     }

   // จำกัดจำนวนแท่งไม่ให้เกิน InpMaxBars (ตัดแท่งเก่าออก เก็บแท่งล่าสุดไว้)
   bool truncated = false;
   if(startShift - endShift + 1 > InpMaxBars)
     {
      startShift = endShift + InpMaxBars - 1;
      truncated  = true;
      Print("ATR ZigZag Export: จำนวนแท่งเกิน InpMaxBars=", InpMaxBars,
            " → เลื่อนวันเริ่มต้นเป็น ", FmtTime(iTime(sym, PERIOD_M1, startShift)));
     }

   // ต้องมีแท่ง warm-up ก่อนแท่งเริ่มต้นอย่างน้อย WARMUP_BARS แท่ง
   int warmupBars = oldestShift - startShift;
   if(warmupBars < WARMUP_BARS)
     {
      Comment("");
      AlertHistory(sym, "แท่ง warm-up ก่อนวันเริ่มต้นไม่พอ (มี " + IntegerToString(warmupBars) + " แท่ง)");
      return;
     }

   //=================================================================
   // 3) คัดลอกข้อมูล M1 + ATR ลง array (ลองใหม่ถ้ามีแท่งใหม่เกิดระหว่างคัดลอก)
   //=================================================================
   datetime startTime = iTime(sym, PERIOD_M1, startShift);
   datetime endTime   = iTime(sym, PERIOD_M1, endShift);
   int      loadRes   = -1;
   for(int attempt = 0; attempt < 3 && loadRes == -1; attempt++)
     {
      startShift = iBarShift(sym, PERIOD_M1, startTime, true);
      endShift   = iBarShift(sym, PERIOD_M1, endTime,   true);
      if(startShift < 1 || endShift < 1 || endShift > startShift)
         break;
      loadRes = LoadData(sym, startShift, endShift);
     }
   if(loadRes == 0)
     {
      Comment("");
      Print("ATR ZigZag Export: ผู้ใช้หยุดการทำงาน");
      return;
     }
   if(loadRes != 1)
     {
      Comment("");
      Alert("ATR ZigZag Export: คัดลอกข้อมูล M1 ไม่สำเร็จ (ข้อมูลเปลี่ยนระหว่างคัดลอก) กรุณารันใหม่อีกครั้ง");
      return;
     }
   int n = ArraySize(g_time);

   //=================================================================
   // 4) คำนวณ ATR ZigZag
   //=================================================================
   int skipped = ComputeZigZag(n);
   if(skipped < 0)
     {
      Comment("");
      Print("ATR ZigZag Export: ผู้ใช้หยุดการทำงาน");
      return;
     }

   //=================================================================
   // 5) เขียนไฟล์ CSV
   //=================================================================
   string fileName = SanitizeFileName(InpFilePrefix + sym) +
                     "_M1_ZZ" + FmtMultiplier(InpATRMultiplier) +
                     "ATR" + IntegerToString(InpATRPeriod) + "_" +
                     FmtYmd(g_time[0]) + "-" + FmtYmd(g_time[n - 1]) + ".csv";
   string filePath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL4\\Files\\" + fileName;

   ResetLastError();
   int fh = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(fh == INVALID_HANDLE)
     {
      int err = GetLastError();
      Comment("");
      Alert("ATR ZigZag Export: เปิดไฟล์ไม่สำเร็จ ", fileName, " error=", err);
      return;
     }

   string e1 = IntegerToString(InpEMA1);
   string e2 = IntegerToString(InpEMA2);
   string e3 = IntegerToString(InpEMA3);

   // แถว header
   string header = "pivot_time,type,pivot_price,open,high,low,close,tick_volume,atr," +
                   "swing_size,swing_atr,bars_from_prev,minutes_from_prev," +
                   "ema" + e1 + ",ema" + e2 + ",ema" + e3 + ",macd_main,macd_signal,macd_hist," +
                   "confirm_time,available_time,confirm_bars";
   if(InpExportConfirmBarValues)
      header += ",c_close,c_atr,c_ema" + e1 + ",c_ema" + e2 + ",c_ema" + e3 +
                ",c_macd_main,c_macd_signal,c_macd_hist";
   FileWrite(fh, header);

   int    cntHigh = 0, cntLow = 0;
   double sumSwingAtr = 0.0, sumConfirm = 0.0;
   int    cntSwing = 0;

   for(int i = 0; i < g_pvCount; i++)
     {
      int    k     = g_pvIdx[i];
      int    ck    = g_pvConf[i];
      int    type  = g_pvType[i];
      double price = (type == PIVOT_HIGH) ? g_high[k] : g_low[k];

      if(type == PIVOT_HIGH) cntHigh++;
      else                   cntLow++;

      // ค่าเทียบกับจุดก่อนหน้า (จุดแรกเว้นว่าง)
      string swingStr = "", swingAtrStr = "", barsPrevStr = "", minsPrevStr = "";
      if(i > 0)
        {
         int    pk        = g_pvIdx[i - 1];
         double prevPrice = (g_pvType[i - 1] == PIVOT_HIGH) ? g_high[pk] : g_low[pk];
         double swing     = MathAbs(price - prevPrice);
         swingStr    = FmtExt(swing);
         barsPrevStr = IntegerToString(k - pk);
         minsPrevStr = IntegerToString(((long)g_time[k] - (long)g_time[pk]) / 60);
         if(IsValidAtr(g_atr[k]))
           {
            double swingAtr = swing / g_atr[k];
            swingAtrStr = DoubleToString(swingAtr, 2);
            sumSwingAtr += swingAtr;
            cntSwing++;
           }
        }

      int confirmBars = ck - k;
      sumConfirm += confirmBars;

      string line = FmtTime(g_time[k]) + "," +
                    ((type == PIVOT_HIGH) ? "HIGH" : "LOW") + "," +
                    FmtPrice(price) + "," +
                    FmtPrice(g_open[k]) + "," + FmtPrice(g_high[k]) + "," +
                    FmtPrice(g_low[k]) + "," + FmtPrice(g_close[k]) + "," +
                    IntegerToString(g_vol[k]) + "," +
                    FmtExt(g_atr[k]) + "," +
                    swingStr + "," + swingAtrStr + "," + barsPrevStr + "," + minsPrevStr + "," +
                    IndicatorFields(sym, g_time[k]) + "," +
                    FmtTime(g_time[ck]) + "," +
                    FmtTime((datetime)(g_time[ck] + 60)) + "," +
                    IntegerToString(confirmBars);

      // ค่า ณ แท่งยืนยัน (ใช้ได้จริงตั้งแต่ available_time)
      if(InpExportConfirmBarValues)
         line += "," + FmtPrice(g_close[ck]) + "," + FmtExt(g_atr[ck]) + "," +
                 IndicatorFields(sym, g_time[ck]);

      FileWrite(fh, line);
     }
   FileClose(fh);

   //=================================================================
   // 6) สรุปผล
   //=================================================================
   double avgSwingAtr = (cntSwing > 0)  ? sumSwingAtr / cntSwing : 0.0;
   double avgConfirm  = (g_pvCount > 0) ? sumConfirm / g_pvCount : 0.0;
   double elapsedSec  = (GetTickCount() - startTick) / 1000.0;

   string summary = "ATR ZigZag Export เสร็จสิ้น | " + sym + " M1" +
                    " | แท่งที่ประมวลผล = " + IntegerToString(n) +
                    (truncated ? " (ถูกจำกัดด้วย InpMaxBars)" : "") +
                    " | ช่วงข้อมูล = " + FmtTime(g_time[0]) + " ถึง " + FmtTime(g_time[n - 1]) +
                    " | HIGH = " + IntegerToString(cntHigh) + ", LOW = " + IntegerToString(cntLow) +
                    " | เฉลี่ย swing_atr = " + DoubleToString(avgSwingAtr, 2) +
                    " | เฉลี่ย confirm_bars = " + DoubleToString(avgConfirm, 2) +
                    " | แท่งที่ข้าม (ATR ใช้ไม่ได้) = " + IntegerToString(skipped) +
                    " | เวลาที่ใช้ = " + DoubleToString(elapsedSec, 2) + " วินาที" +
                    " | ไฟล์ = " + filePath;
   Comment("");
   Print(summary);
   Alert(summary);
  }
//+------------------------------------------------------------------+
