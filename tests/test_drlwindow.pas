program test_drlwindow;

{$mode objfpc}{$H+}

uses
  SysUtils, drlwindow;

procedure AssertSize(
  const aName: AnsiString;
  aExpectedWidth, aExpectedHeight: Integer;
  const aActual: TDRLWindowSize
);
begin
  if (aActual.Width <> aExpectedWidth) or
     (aActual.Height <> aExpectedHeight) then
    raise Exception.CreateFmt(
      '%s: expected %dx%d, got %dx%d',
      [aName, aExpectedWidth, aExpectedHeight, aActual.Width, aActual.Height]
    );
end;

procedure AssertMetrics(
  const aName: AnsiString;
  aWindowWidth, aWindowHeight, aPixelWidth, aPixelHeight: Integer;
  const aActual: TDRLWindowMetrics
);
begin
  AssertSize(aName + ' window', aWindowWidth, aWindowHeight, aActual.WindowSize);
  AssertSize(aName + ' pixels', aPixelWidth, aPixelHeight, aActual.PixelSize);
end;

begin
  AssertSize(
    'keeps a fitting window unchanged',
    1280, 720,
    FitWindowSize(1280, 720, 1480, 900)
  );
  AssertSize(
    'shrinks an oversized window while preserving aspect ratio',
    1440, 900,
    FitWindowSize(1920, 1200, 1480, 900)
  );
  AssertSize(
    'uses the available area for automatic resolution',
    1480, 900,
    FitWindowSize(0, 0, 1480, 900)
  );
  AssertSize(
    'never returns a size larger than the usable area',
    1, 1,
    FitWindowSize(640, 480, 1, 1)
  );
  AssertMetrics(
    'Retina explicit resolution',
    960, 600, 1920, 1200,
    ResolveWindowMetrics(1920, 1200, 1466, 916, 2.0)
  );
  AssertMetrics(
    'Retina automatic resolution',
    1466, 916, 2932, 1832,
    ResolveWindowMetrics(0, 0, 1466, 916, 2.0)
  );
  AssertMetrics(
    'Retina oversized resolution',
    1410, 916, 2820, 1832,
    ResolveWindowMetrics(3024, 1964, 1466, 916, 2.0)
  );
  AssertMetrics(
    'standard density resolution',
    1280, 720, 1280, 720,
    ResolveWindowMetrics(1280, 720, 1466, 916, 1.0)
  );
  AssertMetrics(
    'invalid density fallback',
    1280, 720, 1280, 720,
    ResolveWindowMetrics(1280, 720, 1466, 916, 0.0)
  );
  WriteLn('test_drlwindow: PASS');
end.
