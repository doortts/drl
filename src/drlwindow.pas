unit drlwindow;

{$mode objfpc}{$H+}

interface

type
  TDRLWindowSize = record
    Width: Integer;
    Height: Integer;
  end;

  TDRLWindowMetrics = record
    WindowSize: TDRLWindowSize;
    PixelSize: TDRLWindowSize;
  end;

function FitWindowSize(
  aRequestedWidth, aRequestedHeight,
  aAvailableWidth, aAvailableHeight: Integer
): TDRLWindowSize;
function NormalizePixelDensity(aDensity: Single): Single;
function SelectPreWindowPixelDensity(
  aContentScale, aModePixelDensity: Single
): Single;
function ResolveWindowMetrics(
  aRequestedPixelWidth, aRequestedPixelHeight,
  aAvailableWindowWidth, aAvailableWindowHeight: Integer;
  aPixelDensity: Single
): TDRLWindowMetrics;

implementation

uses Math;

function FitWindowSize(
  aRequestedWidth, aRequestedHeight,
  aAvailableWidth, aAvailableHeight: Integer
): TDRLWindowSize;
begin
  if aAvailableWidth < 1 then aAvailableWidth := 1;
  if aAvailableHeight < 1 then aAvailableHeight := 1;

  if (aRequestedWidth < 1) or (aRequestedHeight < 1) then
  begin
    Result.Width := aAvailableWidth;
    Result.Height := aAvailableHeight;
    Exit;
  end;

  if (aRequestedWidth <= aAvailableWidth) and
     (aRequestedHeight <= aAvailableHeight) then
  begin
    Result.Width := aRequestedWidth;
    Result.Height := aRequestedHeight;
    Exit;
  end;

  if Int64(aRequestedWidth) * aAvailableHeight >
     Int64(aRequestedHeight) * aAvailableWidth then
  begin
    Result.Width := aAvailableWidth;
    Result.Height := Int64(aRequestedHeight) * aAvailableWidth div aRequestedWidth;
    if Result.Height < 1 then Result.Height := 1;
  end
  else
  begin
    Result.Height := aAvailableHeight;
    Result.Width := Int64(aRequestedWidth) * aAvailableHeight div aRequestedHeight;
    if Result.Width < 1 then Result.Width := 1;
  end;
end;

function NormalizePixelDensity(aDensity: Single): Single;
begin
  if aDensity <= 0.0 then Exit(1.0);
  Exit(aDensity);
end;

function SelectPreWindowPixelDensity(
  aContentScale, aModePixelDensity: Single
): Single;
begin
  if aModePixelDensity > 0.0 then
    Exit(aModePixelDensity);
  Exit(NormalizePixelDensity(aContentScale));
end;

function ResolveWindowMetrics(
  aRequestedPixelWidth, aRequestedPixelHeight,
  aAvailableWindowWidth, aAvailableWindowHeight: Integer;
  aPixelDensity: Single
): TDRLWindowMetrics;
var iDensity: Single;
    iAvailablePixels: TDRLWindowSize;
    iFittedPixels: TDRLWindowSize;
begin
  if aAvailableWindowWidth < 1 then aAvailableWindowWidth := 1;
  if aAvailableWindowHeight < 1 then aAvailableWindowHeight := 1;

  iDensity := NormalizePixelDensity(aPixelDensity);
  iAvailablePixels.Width := Max(1, Round(aAvailableWindowWidth * iDensity));
  iAvailablePixels.Height := Max(1, Round(aAvailableWindowHeight * iDensity));
  iFittedPixels := FitWindowSize(
    aRequestedPixelWidth, aRequestedPixelHeight,
    iAvailablePixels.Width, iAvailablePixels.Height
  );

  Result.WindowSize.Width := Min(
    aAvailableWindowWidth,
    Max(1, Round(iFittedPixels.Width / iDensity))
  );
  Result.WindowSize.Height := Min(
    aAvailableWindowHeight,
    Max(1, Round(iFittedPixels.Height / iDensity))
  );
  Result.PixelSize.Width := Max(1, Round(Result.WindowSize.Width * iDensity));
  Result.PixelSize.Height := Max(1, Round(Result.WindowSize.Height * iDensity));
end;

end.
