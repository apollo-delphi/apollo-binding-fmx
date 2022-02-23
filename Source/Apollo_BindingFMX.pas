unit Apollo_BindingFMX;

interface

uses
  Apollo_Binding_Core,
  FMX.Edit,
  FMX.Memo,
  System.Rtti;

type
  TBindingFMX = class(TBindingEngine)
  private
    procedure ApplyToEdit(aEdit: TEdit; aBindItem: TBindItem; const aValue: string);
    procedure ApplyToMemo(aMemo: TMemo; aBindItem: TBindItem; const aValue: string);
    procedure EditOnChange(Sender: TObject);
    procedure MemoOnChange(Sender: TObject);
  protected
    function GetSourceFromControl(aControl: TObject): TObject; override;
    function IsValidControl(aControl: TObject; out aControlName: string;
      out aChildControls: TArray<TObject>): Boolean; override;
    procedure ApplyToControls(aBindItem: TBindItem; aRttiProperty: TRttiProperty); override;
  end;

  TBind = class
  public
    class procedure Bind(aSource: TObject; aRootControl: TObject; const aControlNamePrefix: string = ''); static;
    class procedure Notify(aSource: TObject); static;
  end;

var
  gBindingFMX: TBindingFMX;

implementation

uses
  FMX.Controls,
  FMX.StdCtrls,
  System.Classes,
  System.SysUtils;

{ TBind }

class procedure TBind.Bind(aSource, aRootControl: TObject;
  const aControlNamePrefix: string);
begin
  gBindingFMX.Bind(aSource, aRootControl, aControlNamePrefix);
end;

class procedure TBind.Notify(aSource: TObject);
begin
  gBindingFMX.Notify(aSource);
end;

{ TBindingFMX }

procedure TBindingFMX.ApplyToControls(aBindItem: TBindItem;
  aRttiProperty: TRttiProperty);
var
  Control: TObject;
  Source: TObject;
begin
  Control := aBindItem.Control;
  Source := aBindItem.Source;

  if Control.InheritsFrom(TEdit) then
    ApplyToEdit(TEdit(Control), aBindItem, PropertyValToStr(aRttiProperty, Source))
  else
  if Control.InheritsFrom(TMemo) then
    ApplyToMemo(TMemo(Control), aBindItem, PropertyValToStr(aRttiProperty, Source))
  else
    raise Exception.CreateFmt('TBindingFMX: Control class %s does not support.', [Control.ClassName]);
end;

procedure TBindingFMX.ApplyToEdit(aEdit: TEdit; aBindItem: TBindItem;
  const aValue: string);
begin
  aEdit.Text := aValue;

  SetNativeEvent(aBindItem.New, aEdit, TMethod(aEdit.OnChange));
  aEdit.OnChange := EditOnChange;
end;

procedure TBindingFMX.ApplyToMemo(aMemo: TMemo; aBindItem: TBindItem;
  const aValue: string);
begin
  aMemo.Text := aValue;

  SetNativeEvent(aBindItem.New, aMemo, TMethod(aMemo.OnChange));
  aMemo.OnChange := MemoOnChange;
end;

procedure TBindingFMX.EditOnChange(Sender: TObject);
var
  BindItem: TBindItem;
  Edit: TCustomEdit;
  Method: TMethod;
  NotifyEvent: TNotifyEvent;
begin
  Edit := Sender as TCustomEdit;
  BindItem := GetFirstBindItemHavingProp(Edit);

  BindItem.SetNewValue(Edit.Text);

  if TryGetNativeEvent(Edit, {out}Method) then
  begin
    TMethod(NotifyEvent) := Method;
    NotifyEvent(Sender);
  end;
end;

function TBindingFMX.GetSourceFromControl(aControl: TObject): TObject;
begin
  Result := nil;
end;

function TBindingFMX.IsValidControl(aControl: TObject; out aControlName: string;
  out aChildControls: TArray<TObject>): Boolean;
var
  Control: TControl;
  i: Integer;
begin
  if aControl.InheritsFrom(TControl) and
     not(aControl.InheritsFrom(TLabel))
  then
  begin
    if aControl.InheritsFrom(TPanel) then
      Result := False
    else
      Result := True;

    Control := aControl as TControl;
    aControlName := Control.Name;

    aChildControls := [];
    if Control.ControlsCount > 0 then
    begin
      for i := 0 to Control.ControlsCount - 1 do
        aChildControls := aChildControls + [Control.Controls[i]];
    end;
  end
  else
    Result := False;
end;

procedure TBindingFMX.MemoOnChange(Sender: TObject);
var
  BindItem: TBindItem;
  Memo: TMemo;
  Method: TMethod;
  NotifyEvent: TNotifyEvent;
begin
  Memo := Sender as TMemo;
  BindItem := GetFirstBindItemHavingProp(Memo);

  BindItem.SetNewValue(Memo.Text);

  if TryGetNativeEvent(Memo, {out}Method) then
  begin
    TMethod(NotifyEvent) := Method;
    NotifyEvent(Sender);
  end;
end;

initialization
  gBindingFMX := TBindingFMX.Create;

finalization
  gBindingFMX.Free;

end.
