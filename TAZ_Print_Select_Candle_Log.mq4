//+------------------------------------------------------------------+
//|                                TAZ Print Select Candle Log.mq4  |
//|            Click on the chart to log candle & indicator data     |
//+------------------------------------------------------------------+
#property copyright "TAZ"
#property strict
#property indicator_chart_window
#property indicator_buffers 0

//--- EMA periods
input int InpEMA1Period = 5;
input int InpEMA2Period = 10;
input int InpEMA3Period = 21;
input int InpEMA4Period = 50;
input int InpEMA5Period = 100;

//--- MACD parameters
input int InpMACDFastEMA   = 12;
input int InpMACDSlowEMA   = 26;
input int InpMACDSignalSMA = 9;

//--- ATR parameter
input int InpATRPeriod = 14;

//--- click detection tolerance, in pixels, added above/below the candle's high/low
input int InpClickTolerancePixels = 3;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                 const int prev_calculated,
                 const datetime &time[],
                 const double &open[],
                 const double &high[],
                 const double &low[],
                 const double &close[],
                 const long &tick_volume[],
                 const long &volume[],
                 const int &spread[])
  {
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| ChartEvent function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                   const long &lparam,
                   const double &dparam,
                   const string &sparam)
  {
   if(id != CHARTEVENT_CLICK)
      return;

   int    x = (int)lparam;
   int    y = (int)dparam;
   datetime clickedTime;
   double   clickedPrice;
   int      window;

   if(!ChartXYToTimePrice(0, x, y, window, clickedTime, clickedPrice))
      return;

   int shift = iBarShift(Symbol(), Period(), clickedTime, false);
   if(shift < 0)
      return;

   if(!IsClickOnCandle(window, x, y, shift))
      return;

   PrintCandleLog(shift);
  }

//+------------------------------------------------------------------+
//| Check whether the click landed on the candle body/wick itself,   |
//| not on empty chart space, using a small pixel tolerance          |
//+------------------------------------------------------------------+
bool IsClickOnCandle(const int window, const int clickX, const int clickY, const int shift)
  {
   datetime barTime = iTime(Symbol(), Period(), shift);
   double   barHigh = iHigh(Symbol(), Period(), shift);
   double   barLow  = iLow(Symbol(), Period(), shift);

   int xBarStart, yHigh, xNext, yUnused;
   if(!ChartTimePriceToXY(0, window, barTime, barHigh, xBarStart, yHigh))
      return(false);

   int yLow;
   if(!ChartTimePriceToXY(0, window, barTime, barLow, xNext, yLow))
      return(false);

   datetime nextBarTime = barTime + PeriodSeconds();
   if(!ChartTimePriceToXY(0, window, nextBarTime, barHigh, xNext, yUnused))
      return(false);

   int halfWidth = MathAbs(xNext - xBarStart) / 2;
   if(halfWidth < 1)
      halfWidth = 1;

   bool withinX = (MathAbs(clickX - xBarStart) <= halfWidth + InpClickTolerancePixels);
   bool withinY = (clickY >= yHigh - InpClickTolerancePixels && clickY <= yLow + InpClickTolerancePixels);

   return(withinX && withinY);
  }

//+------------------------------------------------------------------+
//| Print detailed log for the selected candle                       |
//+------------------------------------------------------------------+
void PrintCandleLog(const int shift)
  {
   datetime barTime  = iTime(Symbol(), Period(), shift);
   double   barOpen  = iOpen(Symbol(), Period(), shift);
   double   barHigh  = iHigh(Symbol(), Period(), shift);
   double   barLow   = iLow(Symbol(), Period(), shift);
   double   barClose = iClose(Symbol(), Period(), shift);
   long     barTickVolume = iVolume(Symbol(), Period(), shift);

   double ema1 = iMA(Symbol(), Period(), InpEMA1Period, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema2 = iMA(Symbol(), Period(), InpEMA2Period, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema3 = iMA(Symbol(), Period(), InpEMA3Period, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema4 = iMA(Symbol(), Period(), InpEMA4Period, 0, MODE_EMA, PRICE_CLOSE, shift);
   double ema5 = iMA(Symbol(), Period(), InpEMA5Period, 0, MODE_EMA, PRICE_CLOSE, shift);

   double macdMain   = iMACD(Symbol(), Period(), InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, PRICE_CLOSE, MODE_MAIN, shift);
   double macdSignal = iMACD(Symbol(), Period(), InpMACDFastEMA, InpMACDSlowEMA, InpMACDSignalSMA, PRICE_CLOSE, MODE_SIGNAL, shift);

   double atr = iATR(Symbol(), Period(), InpATRPeriod, shift);

   int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);

   string line = StringFormat(
      "==== TAZ Candle Log | %s %s | Shift=%d | Time=%s | O=%s H=%s L=%s C=%s Vol=%d | EMA%d=%s EMA%d=%s EMA%d=%s EMA%d=%s EMA%d=%s | MACD Main=%s Signal=%s | ATR%d=%s ====",
      Symbol(), PeriodToString(Period()),
      shift,
      TimeToString(barTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
      DoubleToString(barOpen, digits), DoubleToString(barHigh, digits),
      DoubleToString(barLow, digits), DoubleToString(barClose, digits),
      barTickVolume,
      InpEMA1Period, DoubleToString(ema1, digits),
      InpEMA2Period, DoubleToString(ema2, digits),
      InpEMA3Period, DoubleToString(ema3, digits),
      InpEMA4Period, DoubleToString(ema4, digits),
      InpEMA5Period, DoubleToString(ema5, digits),
      DoubleToString(macdMain, digits), DoubleToString(macdSignal, digits),
      InpATRPeriod, DoubleToString(atr, digits)
      );

   Print(line);
  }

//+------------------------------------------------------------------+
//| Convert timeframe constant to readable string                    |
//+------------------------------------------------------------------+
string PeriodToString(const int period)
  {
   switch(period)
     {
      case PERIOD_M1:  return("M1");
      case PERIOD_M5:  return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H4:  return("H4");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN1");
      default:         return(IntegerToString(period));
     }
  }
//+------------------------------------------------------------------+
