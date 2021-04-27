program Apollo_BindingFMX_Test;

{$STRONGLINKTYPES ON}

{DEFINE UseVCL}
{$DEFINE UseFMX}

uses
  {$IFDEF UseVCL}
  VCL.Forms,
  DUnitX.Loggers.GUI.VCL,
  {$ENDIF }
  {$IFDEF UseFMX}
  FMX.Forms,
  DUnitX.Loggers.GUIX,
  {$ENDIF }

  System.SysUtils,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  tstApollo_BindingFMX in 'tstApollo_BindingFMX.pas',
  Apollo_BindingFMX in 'Apollo_BindingFMX.pas',
  Apollo_Binding_Core in '..\Vendors\Apollo_Binding_Core\Apollo_Binding_Core.pas';

begin
  Application.Initialize;
  Application.Title := 'DUnitX';
  {$IFDEF UseFMX}
  Application.CreateForm(TGUIXTestRunner, GUIXTestRunner);
  {$ENDIF}
  {$IFDEF UseVCL}
  Application.CreateForm(TGUIVCLTestRunner, GUIVCLTestRunner);
  {$ENDIF}
  Application.Run;
end.
