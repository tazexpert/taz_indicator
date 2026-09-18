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
     {
      Print("TAZ Print Select Candle Log: unable to convert click coordinates to time/price.");
      return;
     }

   int shift = iBarShift(Symbol(), Period(), clickedTime, false);
   if(shift < 0)
     {
      Print("TAZ Print Select Candle Log: no candle found for the clicked time.");
      return;
     }

   PrintCandleLog(shift);
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

   Print("====================================================");
   Print("TAZ Print Select Candle Log - ", Symbol(), " ", PeriodToString(Period()));
   Print("Shift        : ", shift);
   Print("Time         : ", TimeToString(barTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   Print("Open         : ", DoubleToString(barOpen, digits));
   Print("High         : ", DoubleToString(barHigh, digits));
   Print("Low          : ", DoubleToString(barLow, digits));
   Print("Close        : ", DoubleToString(barClose, digits));
   Print("Tick Volume  : ", barTickVolume);
   Print("----------------------------------------------------");
   Print("EMA(", InpEMA1Period, ")     : ", DoubleToString(ema1, digits));
   Print("EMA(", InpEMA2Period, ")    : ", DoubleToString(ema2, digits));
   Print("EMA(", InpEMA3Period, ")    : ", DoubleToString(ema3, digits));
   Print("EMA(", InpEMA4Period, ")    : ", DoubleToString(ema4, digits));
   Print("EMA(", InpEMA5Period, ")   : ", DoubleToString(ema5, digits));
   Print("----------------------------------------------------");
   Print("MACD Main    : ", DoubleToString(macdMain, digits));
   Print("MACD Signal  : ", DoubleToString(macdSignal, digits));
   Print("----------------------------------------------------");
   Print("ATR(", InpATRPeriod, ")     : ", DoubleToString(atr, digits));
   Print("====================================================");
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
