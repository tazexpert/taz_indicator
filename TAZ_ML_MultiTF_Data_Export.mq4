//+------------------------------------------------------------------+
//|                            TAZ ML MultiTF Data Export.mq4        |
//|   Export multi-timeframe indicator features and future targets   |
//|   to CSV for Machine Learning training                           |
//+------------------------------------------------------------------+
#property copyright "TAZ"
#property strict
#property show_inputs

//--- Lookahead for target/label calculation
input int LookAheadBars = 5;

//--- Number of most recent bars to export
input int InpExportBars = 100;

//--- EMA periods (used on CTF, H1 and H4)
input int InpEMA1Period = 21;
input int InpEMA2Period = 50;
input int InpEMA3Period = 100;
input int InpEMA4Period = 200;

//--- RSI period
input int InpRSIPeriod = 14;

//--- ATR period (CTF only)
input int InpATRPeriod = 14;

//--- MACD parameters
input int InpMACDFastEMA   = 12;
input int InpMACDSlowEMA   = 26;
input int InpMACDSignalSMA = 9;

//--- output file name
input string InpFileName = "TAZ_ML_MultiTF_Data.csv";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   int totalBars = Bars;

   int startBar = totalBars - InpExportBars;
   int endBar   = LookAheadBars + 1;

   if(startBar < endBar)
     {
      Print("TAZ ML Export: Not enough history bars to export. Bars=", totalBars,
            " Required startBar=", startBar, " endBar=", endBar);
      return;
     }

   int handle = FileOpen(InpFileName, FILE_WRITE | FILE_CSV, ',');
   if(handle == INVALID_HANDLE)
     {
      Print("TAZ ML Export: Failed to open file ", InpFileName, " Error=", GetLastError());
      return;
     }

   WriteHeader(handle);

   //--- track previous bar's EMA and MACD values to detect crossovers
   double prevEMAFastCTF  = EMPTY_VALUE;
   double prevEMASlowCTF  = EMPTY_VALUE;
   double prevMACDMainCTF = EMPTY_VALUE;
   bool   havePrev = false;

   int rowsWritten = 0;

   //--- loop from oldest bar to newest bar within the requested range
   for(int i = startBar; i >= endBar; i--)
     {
      //--- Current timeframe (CTF) OHLCV
      datetime barTime  = Time[i];
      double   barOpen  = Open[i];
      double   barHigh  = High[i];
      double   barLow   = Low[i];
      double   barClose = Close[i];
      long     barVolume = Volume[i];

      //--- CTF indicators
      double rsiCTF = iRSI(NULL, 0, InpRSIPeriod, PRICE_CLOSE, i);
      double atrCTF = iATR(NULL, 0, InpATRPeriod, i);

      double ema21CTF  = iMA(NULL, 0, InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema50CTF  = iMA(NULL, 0, InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema100CTF = iMA(NULL, 0, InpEMA3Period, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema200CTF = iMA(NULL, 0, InpEMA4Period, 0, MODE_EMA, PRICE_CLOSE, i);

      double emaDistanceCTF = ema21CTF - ema50CTF;

      double macdMainCTF   = iMACD(NULL, 0, InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, PRICE_CLOSE, MODE_MAIN, i);
      double macdSignalCTF = iMACD(NULL, 0, InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, PRICE_CLOSE, MODE_SIGNAL, i);

      //--- EMA 21/50 crossover flag, compared against the previous (older) processed bar
      int emaCrossover = 0;
      int macdZeroCrossover = 0;
      if(havePrev)
        {
         if(prevEMAFastCTF <= prevEMASlowCTF && ema21CTF > ema50CTF)
            emaCrossover = 1;
         else if(prevEMAFastCTF >= prevEMASlowCTF && ema21CTF < ema50CTF)
            emaCrossover = -1;

         if(prevMACDMainCTF <= 0.0 && macdMainCTF > 0.0)
            macdZeroCrossover = 1;
         else if(prevMACDMainCTF >= 0.0 && macdMainCTF < 0.0)
            macdZeroCrossover = -1;
        }

      prevEMAFastCTF  = ema21CTF;
      prevEMASlowCTF  = ema50CTF;
      prevMACDMainCTF = macdMainCTF;
      havePrev = true;

      //--- CRITICAL MTF ALIGNMENT: locate the corresponding H1 and H4 bars
      int shiftH1 = iBarShift(NULL, PERIOD_H1, barTime, false);
      int shiftH4 = iBarShift(NULL, PERIOD_H4, barTime, false);

      //--- H1 features
      double ema21H1  = iMA(NULL, PERIOD_H1, InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE, shiftH1);
      double ema50H1  = iMA(NULL, PERIOD_H1, InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE, shiftH1);
      double ema100H1 = iMA(NULL, PERIOD_H1, InpEMA3Period, 0, MODE_EMA, PRICE_CLOSE, shiftH1);
      double ema200H1 = iMA(NULL, PERIOD_H1, InpEMA4Period, 0, MODE_EMA, PRICE_CLOSE, shiftH1);
      double rsiH1    = iRSI(NULL, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE, shiftH1);
      double macdMainH1 = iMACD(NULL, PERIOD_H1, InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, PRICE_CLOSE, MODE_MAIN, shiftH1);

      //--- H4 features
      double ema21H4  = iMA(NULL, PERIOD_H4, InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE, shiftH4);
      double ema50H4  = iMA(NULL, PERIOD_H4, InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE, shiftH4);
      double ema100H4 = iMA(NULL, PERIOD_H4, InpEMA3Period, 0, MODE_EMA, PRICE_CLOSE, shiftH4);
      double ema200H4 = iMA(NULL, PERIOD_H4, InpEMA4Period, 0, MODE_EMA, PRICE_CLOSE, shiftH4);
      double rsiH4    = iRSI(NULL, PERIOD_H4, InpRSIPeriod, PRICE_CLOSE, shiftH4);
      double macdMainH4 = iMACD(NULL, PERIOD_H4, InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, PRICE_CLOSE, MODE_MAIN, shiftH4);

      //--- Targets / labels: future movement from bar i to bar (i - LookAheadBars)
      int futureShift = i - LookAheadBars;

      double targetCloseDiff = Close[futureShift] - barClose;

      int highestIndex = iHighest(NULL, 0, MODE_HIGH, LookAheadBars, futureShift);
      int lowestIndex   = iLowest(NULL, 0, MODE_LOW, LookAheadBars, futureShift);

      double targetMaxHigh = High[highestIndex] - barClose;
      double targetMaxLow  = barClose - Low[lowestIndex];

      WriteRow(handle, digitsOf(),
               barTime, barOpen, barHigh, barLow, barClose, barVolume,
               rsiCTF, atrCTF,
               ema21CTF, ema50CTF, ema100CTF, ema200CTF,
               emaDistanceCTF, emaCrossover,
               macdMainCTF, macdSignalCTF, macdZeroCrossover,
               ema21H1, ema50H1, ema100H1, ema200H1, rsiH1, macdMainH1,
               ema21H4, ema50H4, ema100H4, ema200H4, rsiH4, macdMainH4,
               targetCloseDiff, targetMaxHigh, targetMaxLow);

      rowsWritten++;
     }

   FileClose(handle);

   Print("TAZ ML Export: Finished. Rows written=", rowsWritten, " File=", InpFileName);
  }

//+------------------------------------------------------------------+
//| Return the current chart's price digits                          |
//+------------------------------------------------------------------+
int digitsOf()
  {
   return(Digits);
  }

//+------------------------------------------------------------------+
//| Write the CSV header row                                         |
//+------------------------------------------------------------------+
void WriteHeader(const int handle)
  {
   FileWrite(handle,
      "Timestamp", "Open", "High", "Low", "Close", "Volume",
      "RSI_CTF", "ATR_CTF",
      "EMA21_CTF", "EMA50_CTF", "EMA100_CTF", "EMA200_CTF",
      "EMA_Distance", "EMA_Crossover",
      "MACD_Main_CTF", "MACD_Signal_CTF", "MACD_Zero_Crossover",
      "EMA21_H1", "EMA50_H1", "EMA100_H1", "EMA200_H1", "RSI_H1", "MACD_Main_H1",
      "EMA21_H4", "EMA50_H4", "EMA100_H4", "EMA200_H4", "RSI_H4", "MACD_Main_H4",
      "Target_Close_Diff", "Target_Max_High", "Target_Max_Low");
  }

//+------------------------------------------------------------------+
//| Write a single data row to the CSV file                          |
//+------------------------------------------------------------------+
void WriteRow(const int handle, const int digits,
              const datetime barTime, const double barOpen, const double barHigh,
              const double barLow, const double barClose, const long barVolume,
              const double rsiCTF, const double atrCTF,
              const double ema21CTF, const double ema50CTF, const double ema100CTF, const double ema200CTF,
              const double emaDistanceCTF, const int emaCrossover,
              const double macdMainCTF, const double macdSignalCTF, const int macdZeroCrossover,
              const double ema21H1, const double ema50H1, const double ema100H1, const double ema200H1,
              const double rsiH1, const double macdMainH1,
              const double ema21H4, const double ema50H4, const double ema100H4, const double ema200H4,
              const double rsiH4, const double macdMainH4,
              const double targetCloseDiff, const double targetMaxHigh, const double targetMaxLow)
  {
   FileWrite(handle,
      TimeToString(barTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      DoubleToString(barOpen, digits), DoubleToString(barHigh, digits),
      DoubleToString(barLow, digits), DoubleToString(barClose, digits),
      barVolume,
      DoubleToString(rsiCTF, 4), DoubleToString(atrCTF, digits),
      DoubleToString(ema21CTF, digits), DoubleToString(ema50CTF, digits),
      DoubleToString(ema100CTF, digits), DoubleToString(ema200CTF, digits),
      DoubleToString(emaDistanceCTF, digits), emaCrossover,
      DoubleToString(macdMainCTF, digits), DoubleToString(macdSignalCTF, digits), macdZeroCrossover,
      DoubleToString(ema21H1, digits), DoubleToString(ema50H1, digits),
      DoubleToString(ema100H1, digits), DoubleToString(ema200H1, digits),
      DoubleToString(rsiH1, 4), DoubleToString(macdMainH1, digits),
      DoubleToString(ema21H4, digits), DoubleToString(ema50H4, digits),
      DoubleToString(ema100H4, digits), DoubleToString(ema200H4, digits),
      DoubleToString(rsiH4, 4), DoubleToString(macdMainH4, digits),
      DoubleToString(targetCloseDiff, digits), DoubleToString(targetMaxHigh, digits),
      DoubleToString(targetMaxLow, digits));
  }
//+------------------------------------------------------------------+
