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
  System.Generics.Collections,
  System.Rtti;

type
  TBindItem = class
  strict private
    FControl: TObject;
    FNativeEvent: TNotifyEvent;
    FPropName: string;
    FSource: TObject;
  public
    property Control: TObject read FControl write FControl;
    property NativeEvent: TNotifyEvent read FNativeEvent write FNativeEvent;
    property PropName: string read FPropName write FPropName;
    property Source: TObject read FSource write FSource;
  end;

  TBindingFMX = class(TBindingEngine, IFreeNotification)
  strict private
    FBindItemList: TObjectList<TBindItem>;
    function BindPropertyToControl(aSource: TObject; aRttiProperty: TRttiProperty;
      aControl: TObject): Boolean;
    function GetMatchedSourceProperty(const aCntrNamePrefix: string; aControl: TFmxObject;
      const RttiProperties: TArray<TRttiProperty>): TRttiProperty;
    function PrepareBindItem(aControl: TFmxObject; aSource: TObject;
      aRttiProperty: TRttiProperty): TBindItem;
    procedure AddSourceFreeNotification(aSource: TObject);
    procedure DoBind(aControl: TFmxObject; aSource: TObject; const aCntrNamePrefix: string;
      aRttiProperties: TArray<TRttiProperty>);
    procedure EditOnChangeTracking(Sender: TObject);
    procedure FreeNotification(aObject: TObject); // controls free natification
    procedure SetToEdit(aSource: TObject; aRttiProperty: TRttiProperty; aEdit: TEdit);
    procedure SetToLabel(aSource: TObject; aRttiProperty: TRttiProperty; aLabel: TLabel);
    procedure SetToTreeViewItem(aSource: TObject; aRttiProperty: TRttiProperty; aTreeViewItem: TTreeViewItem);
    procedure SourceFreeNotification(Sender: TObject); // source objects free natification
  private
    function GetBindItem(aControl: TObject): TBindItem;
    function GetBindItems(aSource: TObject): TArray<TBindItem>;
    procedure Bind(aRootControl: TFmxObject; aSource: TObject; const aCntrNamePrefix: string);
    procedure Notify(aSource: TObject);
    procedure SingleBind(aControl: TFmxObject; aSource: TObject);
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TBind = class(TBindAbstract)
  public
    class function GetControls<T: class>(aSource: TObject): TArray<T>;
    class function GetBindItem(aControl: TObject): TBindItem;
    class function GetSource<T: class>(aControl: TObject): T;
    class procedure Bind(aRootControl: TFmxObject; aSource: TObject; const aCntrNamePrefix: string = '');
    class procedure Notify(aSource: TObject);
    class procedure SingleBind(aControl: TFmxObject; aSource: TObject);
  end;

var
  gBindingFMX: TBindingFMX;

implementation

uses
  System.SysUtils,
  System.TypInfo;

{ TBind }

class procedure TBind.Bind(aRootControl: TFmxObject; aSource: TObject;
  const aCntrNamePrefix: string);
begin
  gBindingFMX.Bind(aRootControl, aSource, aCntrNamePrefix);
end;

class function TBind.GetBindItem(aControl: TObject): TBindItem;
begin
  Result := gBindingFMX.GetBindItem(aControl);
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

class function TBind.GetSource<T>(aControl: TObject): T;
begin
  Result := GetBindItem(aControl).Source as T;
end;

class procedure TBind.Notify(aSource: TObject);
begin
  gBindingFMX.Notify(aSource);
end;

class procedure TBind.SingleBind(aControl: TFmxObject; aSource: TObject);
begin
  gBindingFMX.SingleBind(aControl, aSource);
end;

{ TBindingFMX }

procedure TBindingFMX.AddSourceFreeNotification(aSource: TObject);
var
  SourceFreeNotify: ISourceFreeNotification;
begin
  if aSource.GetInterface(ISourceFreeNotification, SourceFreeNotify) and
     (Length(GetBindItems(aSource)) > 0)
  then
    SourceFreeNotify.AddFreeNotify(SourceFreeNotification);
end;

procedure TBindingFMX.Bind(aRootControl: TFmxObject; aSource: TObject;
  const aCntrNamePrefix: string);
var
  RttiContext: TRttiContext;
  RttiProperties: TArray<TRttiProperty>;
begin
  RttiContext := TRttiContext.Create;
  try
    RttiProperties := RttiContext.GetType(aSource.ClassType).GetProperties;
    DoBind(aRootControl, aSource, aCntrNamePrefix, RttiProperties);
    AddSourceFreeNotification(aSource);
  finally
    RttiContext.Free;
  end;
end;

function TBindingFMX.BindPropertyToControl(aSource: TObject;
  aRttiProperty: TRttiProperty; aControl: TObject): Boolean;
begin
  Result := True;

  if aControl is TLabel then
    SetToLabel(aSource, aRttiProperty, TLabel(aControl))
  else
  if aControl is TEdit then
    SetToEdit(aSource, aRttiProperty, TEdit(aControl))
  else
  if aControl.InheritsFrom(TTreeViewItem) then
    SetToTreeViewItem(aSource, aRttiProperty, TTreeViewItem(aControl))
  else
    Result := False;
end;

constructor TBindingFMX.Create;
begin
  FBindItemList := TObjectList<TBindItem>.Create(True);
end;

destructor TBindingFMX.Destroy;
begin
  FBindItemList.Free;

  inherited;
end;

procedure TBindingFMX.DoBind(aControl: TFmxObject; aSource: TObject; const aCntrNamePrefix: string;
  aRttiProperties: TArray<TRttiProperty>);
var
  ChildControl: TFmxObject;
  i: Integer;
  RttiProperty: TRttiProperty;
begin
  for i := 0 to aControl.ChildrenCount - 1 do
  begin
    ChildControl := aControl.Children.Items[i];

    if ChildControl.ChildrenCount > 0 then
      DoBind(ChildControl, aSource, aCntrNamePrefix, aRttiProperties);

    RttiProperty := GetMatchedSourceProperty(aCntrNamePrefix, ChildControl, aRttiProperties);
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
  BindItem := GetBindItem(Sender);

  SetPropValue(BindItem.Source, BindItem.PropName, Edit.Text);

  if Assigned(BindItem.NativeEvent) then
    BindItem.NativeEvent(Sender);
end;

procedure TBindingFMX.FreeNotification(aObject: TObject);
var
  BindItem: TBindItem;
begin
  BindItem := GetBindItem(aObject);

  if Assigned(BindItem) then
    FBindItemList.Remove(BindItem);
end;

function TBindingFMX.GetBindItem(aControl: TObject): TBindItem;
var
  BindItem: TBindItem;
begin
  Result := nil;

  for BindItem in FBindItemList do
    if BindItem.Control = aControl then
      Exit(BindItem);
end;

function TBindingFMX.GetBindItems(aSource: TObject): TArray<TBindItem>;
var
  BindItem: TBindItem;
begin
  Result := [];

  for BindItem in FBindItemList do
    if BindItem.Source = aSource then
      Result := Result + [BindItem];
end;

function TBindingFMX.GetMatchedSourceProperty(const aCntrNamePrefix: string;
  aControl: TFmxObject;
  const RttiProperties: TArray<TRttiProperty>): TRttiProperty;
var
  ControlName: string;
  RttiProperty: TRttiProperty;
begin
  Result := nil;

  for RttiProperty in RttiProperties do
  begin
    if RttiProperty.PropertyType.IsInstance or
       RttiProperty.PropertyType.IsRecord or
       RttiProperty.PropertyType.IsSet
    then
      Continue;

    ControlName := aControl.Name;

    if ControlName.ToUpper.EndsWith((aCntrNamePrefix + RttiProperty.Name).ToUpper) then
      Exit(RttiProperty);
  end;
end;

procedure TBindingFMX.Notify(aSource: TObject);
var
  BindItem: TBindItem;
  BindItems: TArray<TBindItem>;
  RttiContext: TRttiContext;
  RttiProperty: TRttiProperty;
begin
  BindItems := GetBindItems(aSource);

  RttiContext := TRttiContext.Create;
  try
    for BindItem in BindItems do
    begin
      RttiProperty := RttiContext.GetType(aSource.ClassType).GetProperty(BindItem.PropName);
      BindPropertyToControl(aSource, RttiProperty, BindItem.Control);
    end;
  finally
    RttiContext.Free;
  end;
end;

function TBindingFMX.PrepareBindItem(aControl: TFmxObject;
  aSource: TObject; aRttiProperty: TRttiProperty): TBindItem;
begin
  Result := TBindItem.Create;
  Result.Source := aSource;
  Result.Control := aControl;

  if Assigned(aRttiProperty) then
    Result.PropName := aRttiProperty.Name;

  aControl.AddFreeNotify(Self);
end;

procedure TBindingFMX.SetToEdit(aSource: TObject; aRttiProperty: TRttiProperty; aEdit: TEdit);
var
  BindItem: TBindItem;
begin
  aEdit.Text := aRttiProperty.GetValue(aSource).AsString;

  if GetBindItem(aEdit) = nil then
  begin
    BindItem := PrepareBindItem(aEdit, aSource, aRttiProperty);

    if Assigned(aEdit.OnChangeTracking) then
      BindItem.NativeEvent := aEdit.OnChangeTracking;

    FBindItemList.Add(BindItem);

    aEdit.OnChangeTracking := EditOnChangeTracking;
  end;
end;

procedure TBindingFMX.SetToLabel(aSource: TObject; aRttiProperty: TRttiProperty;
  aLabel: TLabel);
var
  BindItem: TBindItem;
begin
  aLabel.Text := aRttiProperty.GetValue(aSource).ToString;

  if GetBindItem(aLabel) = nil then
  begin
    BindItem := PrepareBindItem(aLabel, aSource, aRttiProperty);

    FBindItemList.Add(BindItem);
  end;
end;

procedure TBindingFMX.SetToTreeViewItem(aSource: TObject;
  aRttiProperty: TRttiProperty; aTreeViewItem: TTreeViewItem);
var
  BindItem: TBindItem;
begin
  if Assigned(aRttiProperty) then
    aTreeViewItem.Text := aRttiProperty.GetValue(aSource).AsString;

  if GetBindItem(aTreeViewItem) = nil then
  begin
    BindItem := PrepareBindItem(aTreeViewItem, aSource, aRttiProperty);

    FBindItemList.Add(BindItem);
  end;
end;

procedure TBindingFMX.SingleBind(aControl: TFmxObject; aSource: TObject);
begin
  if BindPropertyToControl(aSource, nil, aControl) then
    AddSourceFreeNotification(aSource);
end;

procedure TBindingFMX.SourceFreeNotification(Sender: TObject);
var
  BindItem: TBindItem;
  BindItems: TArray<TBindItem>;
begin
  BindItems := GetBindItems(Sender);

  for BindItem in BindItems do
    FBindItemList.Remove(BindItem);
end;

initialization
  gBindingFMX := TBindingFMX.Create;

finalization
  gBindingFMX.Free;

end.
