//+------------------------------------------------------------------+
//|                            TAZ ML MultiTF Data Export.mq4        |
//|   Export raw OHLC price history to CSV                          |
//+------------------------------------------------------------------+
#property copyright "TAZ"
#property strict
#property show_inputs

//--- Number of most recent bars to export
input int InpExportBars = 100;

//--- output file name
input string InpFileName = "TAZ_ML_MultiTF_Data.csv";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   int totalBars = Bars;

   //--- export the InpExportBars most recent bars: i=0 is the current (still forming) bar,
   //--- so the most recent CLOSED bar is i=1 and the oldest bar in the export window is i=InpExportBars
   int startBar = InpExportBars;
   int endBar   = 1;

   //--- clamp to the amount of history actually available on the chart
   if(startBar > totalBars - 1)
      startBar = totalBars - 1;

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

   FileWrite(handle, "Timestamp", "Open", "High", "Low", "Close");

   int digits = (int)Digits;
   int rowsWritten = 0;

   //--- loop from oldest bar to newest bar within the requested range
   for(int i = startBar; i >= endBar; i--)
     {
      FileWrite(handle,
         TimeToString(Time[i], TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         DoubleToString(Open[i], digits),
         DoubleToString(High[i], digits),
         DoubleToString(Low[i], digits),
         DoubleToString(Close[i], digits));

      rowsWritten++;
     }

   FileClose(handle);

   Print("TAZ ML Export: Finished. Rows written=", rowsWritten, " File=", InpFileName);
  }
//+------------------------------------------------------------------+
