unit Apollo_BindingFMX;

interface

uses
  Apollo_Binding_Core,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.Objects,
  FMX.TreeView,
  FMX.Types,
  System.Classes,
  System.Rtti;

type
  TBindingFMX = class(TBindingEngine)
  private
    procedure EditOnChangeTracking(Sender: TObject);
    procedure SetToEdit(aEdit: TEdit; const aValue: string; var aBindItem: TBindItem);
    procedure SetToLabel(aLabel: TLabel; const aValue: string; var aBindItem: TBindItem);
    procedure SetToTreeViewItem(aTreeViewItem: TTreeViewItem; const aValue: string; var aBindItem: TBindItem);
  protected
    procedure BindPropertyToControl(aSource: TObject; aRttiProperty: TRttiProperty; aControl: TComponent); override;
    procedure DoBind(aSource: TObject; aControl: TComponent; const aControlNamePrefix: string;
      aRttiProperties: TArray<TRttiProperty>); override;
  end;

  TBind = class
  public
    class function GetControls<T: class>(aSource: TObject): TArray<T>;
    class function GetBindItem(aControl: TFmxObject; const aIndex: Integer = 0): TBindItem;
    class function GetSource<T: class>(aControl: TFmxObject; const aIndex: Integer = 0): T;
    class procedure Bind(aSource: TObject; aRootControl: TFmxObject; const aControlNamePrefix: string = '');
    class procedure Notify(aSource: TObject);
    class procedure SingleBind(aSource: TObject; aControl: TFmxObject; const aIndex: Integer = 0);
  end;

var
  gBindingFMX: TBindingFMX;

implementation

uses
  System.SysUtils,
  System.TypInfo;

{ TBind }

class procedure TBind.Bind(aSource: TObject; aRootControl: TFmxObject; const aControlNamePrefix: string);
begin
  gBindingFMX.Bind(aSource, aRootControl, aControlNamePrefix);
end;

class function TBind.GetBindItem(aControl: TFmxObject; const aIndex: Integer): TBindItem;
begin
  Result := gBindingFMX.GetBindItem(aControl, aIndex);
end;

class function TBind.GetControls<T>(aSource: TObject): TArray<T>;
var
  BindItem: TBindItem;
  BindItems: TArray<TBindItem>;
begin
  Result := [];

  BindItems := gBindingFMX.GetBindItems(aSource);
  for BindItem in BindItems do
    if BindItem.Control is T then
      Result := Result + [BindItem.Control as T];
end;

class function TBind.GetSource<T>(aControl: TFmxObject; const aIndex: Integer = 0): T;
begin
  Result := GetBindItem(aControl, aIndex).Source as T;
end;

class procedure TBind.Notify(aSource: TObject);
begin
  gBindingFMX.Notify(aSource);
end;

class procedure TBind.SingleBind(aSource: TObject; aControl: TFmxObject; const aIndex: Integer);
begin
  gBindingFMX.SingleBind(aSource, aControl, aIndex);
end;

{ TBindingFMX }

procedure  TBindingFMX.BindPropertyToControl(aSource: TObject;
  aRttiProperty: TRttiProperty; aControl: TComponent);
var
  BindItem: TBindItem;
begin
  BindItem := AddBindItem(aSource, aRttiProperty.Name, aControl, 0);

  if aControl is TLabel then
    SetToLabel(TLabel(aControl), aRttiProperty.GetValue(aSource).AsString, BindItem)
  else
  if aControl is TEdit then
    SetToEdit(TEdit(aControl), aRttiProperty.GetValue(aSource).AsString, BindItem)
  else
  if aControl.InheritsFrom(TTreeViewItem) then
    SetToTreeViewItem(TTreeViewItem(aControl), aRttiProperty.GetValue(aSource).AsString, BindItem)
  else
    raise Exception.CreateFmt('TBindingFMX: Control class %s does not supported', [aControl.ClassName]);
end;

procedure TBindingFMX.DoBind(aSource: TObject; aControl: TComponent; const aControlNamePrefix: string;
      aRttiProperties: TArray<TRttiProperty>);
var
  ChildControl: TFmxObject;
  Control: TFmxObject;
  i: Integer;
  RttiProperty: TRttiProperty;
begin
  Control := aControl as TFmxObject;

  for i := 0 to Control.ChildrenCount - 1 do
  begin
    ChildControl := Control.Children.Items[i];

    if ChildControl.ChildrenCount > 0 then
      DoBind(aSource, ChildControl, aControlNamePrefix, aRttiProperties);

    RttiProperty := GetMatchedSourceProperty(aControlNamePrefix, ChildControl.Name, aRttiProperties);
    if Assigned(RttiProperty) then
      BindPropertyToControl(aSource, RttiProperty, ChildControl);
  end;
end;

procedure TBindingFMX.EditOnChangeTracking(Sender: TObject);
var
  BindItem: TBindItem;
  Edit: TEdit;
begin
  Edit := Sender as TEdit;
  BindItem := GetBindItem(Edit);

  SetPropValue(BindItem.Source, BindItem.PropName, Edit.Text);

  if Assigned(BindItem.NativeEvent) then
    BindItem.NativeEvent(Sender);
end;

procedure TBindingFMX.SetToEdit(aEdit: TEdit; const aValue: string; var aBindItem: TBindItem);
begin
  aEdit.Text := aValue;

  if Assigned(aEdit.OnChangeTracking) then
    aBindItem.NativeEvent := aEdit.OnChangeTracking;

  aEdit.OnChangeTracking := EditOnChangeTracking;
end;

procedure TBindingFMX.SetToLabel(aLabel: TLabel; const aValue: string; var aBindItem: TBindItem);
begin
  aLabel.Text := aValue;
end;

procedure TBindingFMX.SetToTreeViewItem(aTreeViewItem: TTreeViewItem; const aValue: string; var aBindItem: TBindItem);
begin
  aTreeViewItem.Text := aValue;
end;

initialization
  gBindingFMX := TBindingFMX.Create;

finalization
  gBindingFMX.Free;

end.
