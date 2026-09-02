(*
MIT License

Copyright (c) 2026 by.LaoZhang qq600585

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*)
{ ****************************************************************************** }
{ * json object library for delphi/objfpc                                      * }
{ ****************************************************************************** }

unit Z.Json;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses SysUtils,
{$IFDEF DELPHI}
  Z.Delphi.JsonDataObjects,
{$ELSE DELPHI}
  Z.FPC.GenericList,
  fpjson, jsonparser, jsonscanner,
{$ENDIF DELPHI}
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.Status,
  Z.UnicodeMixedLib,
  Z.MemoryStream,
  Z.Int128;

type
  TZ_JsonObject = class;

{$IFDEF DELPHI}
  TZ_Instance_JsonArray = TJsonArray;
  TZ_Instance_JsonObject = TJsonObject;
  TZ_JsonString = TPascalString;
{$ELSE DELPHI}
  TZ_Instance_JsonArray = TJsonArray;
  TZ_Instance_JsonObject = TJsonObject;
  TZ_JsonString = TUPascalString;
{$ENDIF DELPHI}

  TZ_JsonBase = class(TCore_Object_Intermediate)
  protected
    FParent: TZ_JsonBase;
    FList: TCore_ObjectList;
  public
    property Parent: TZ_JsonBase read FParent;
    constructor Create(Parent_: TZ_JsonBase); virtual;
    destructor Destroy; override;
  end;

  TZ_JsonArray = class(TZ_JsonBase)
  private
    FInstance: TZ_Instance_JsonArray;
  public
    property Instance: TZ_Instance_JsonArray read FInstance;
    constructor Create(Parent_: TZ_JsonBase); override;
    destructor Destroy; override;

    procedure Clear;
    procedure Delete(Index: integer);

    procedure Add(const v_: string); overload;
    procedure Add(const v_: TZ_JsonString); overload;
    procedure Add(const v_: integer); overload;
    procedure Add(const v_: int64); overload;
    procedure Add(const v_: uint64); overload;
    procedure Add(const v_: Int128); overload;
    procedure Add(const v_: UInt128); overload;
    procedure AddF(const v_: double); overload;
    procedure Add(const v_: TDateTime); overload;
    procedure Add(const v_: boolean); overload;
    function AddArray: TZ_JsonArray;
    function AddObject: TZ_JsonObject; overload;

    procedure Insert(Index: integer; const v_: string); overload;
    procedure Insert(Index: integer; const v_: TZ_JsonString); overload;
    procedure Insert(Index: integer; const v_: integer); overload;
    procedure Insert(Index: integer; const v_: int64); overload;
    procedure Insert(Index: integer; const v_: uint64); overload;
    procedure Insert(Index: integer; const v_: Int128); overload;
    procedure Insert(Index: integer; const v_: UInt128); overload;
    procedure Insert(Index: integer; const v_: double); overload;
    procedure Insert(Index: integer; const v_: TDateTime); overload;
    procedure Insert(Index: integer; const v_: boolean); overload;
    function InsertArray(Index: integer): TZ_JsonArray;
    function InsertObject(Index: integer): TZ_JsonObject; overload;

    function GetString(Index: integer): string;
    procedure SetString(Index: integer; const Value: string);
    function GetInt(Index: integer): integer;
    procedure SetInt(Index: integer; const Value: integer);
    function GetLong(Index: integer): int64;
    procedure SetLong(Index: integer; const Value: int64);
    function GetULong(Index: integer): uint64;
    procedure SetULong(Index: integer; const Value: uint64);

    function GetInt128(Index: integer): Int128;
    procedure SetInt128(Index: integer; const Value: Int128);
    function GetUInt128(Index: integer): UInt128;
    procedure SetUInt128(Index: integer; const Value: UInt128);

    function GetFloat(Index: integer): double;
    procedure SetFloat(Index: integer; const Value: double);
    function GetDateTime(Index: integer): TDateTime;
    procedure SetDateTime(Index: integer; const Value: TDateTime);
    function GetBool(Index: integer): boolean;
    procedure SetBool(Index: integer; const Value: boolean);
    function GetArray(Index: integer): TZ_JsonArray;
    function GetObject(Index: integer): TZ_JsonObject;

    property S[Index: integer]: string read GetString write SetString;
    property I[Index: integer]: integer read GetInt write SetInt;
    property I32[Index: integer]: integer read GetInt write SetInt;
    property L[Index: integer]: int64 read GetLong write SetLong;
    property I64[Index: integer]: int64 read GetLong write SetLong;
    property I128[Index: integer]: Int128 read GetInt128 write SetInt128;
    property U[Index: integer]: uint64 read GetULong write SetULong;
    property U64[Index: integer]: uint64 read GetULong write SetULong;
    property U128[Index: integer]: UInt128 read GetUInt128 write SetUInt128;
    property F[Index: integer]: double read GetFloat write SetFloat;
    property D[Index: integer]: TDateTime read GetDateTime write SetDateTime;
    property B[Index: integer]: boolean read GetBool write SetBool;
    property A[Index: integer]: TZ_JsonArray read GetArray;
    property O[Index: integer]: TZ_JsonObject read GetObject;

    function GetCount: integer;
    property Count: integer read GetCount;
  end;

  TZ_JsonObject = class(TZ_JsonBase)
  private
    FInstance: TZ_Instance_JsonObject;
    FTag: integer;
  public
    property Tag: integer read FTag write FTag;
    property Instance: TZ_Instance_JsonObject read FInstance;

    constructor Create(); overload;
    constructor Create(Parent_: TZ_JsonBase); overload; override;
    destructor Destroy; override;

    procedure SwapInstance(source_: TZ_JsonObject);
    procedure Assign(source_: TZ_JsonObject);
    function Clone: TZ_JsonObject;

    procedure Clear;
    function IndexOf(const Name: string): integer;
    function Exists(const Name: string): boolean;

    function GetInt128(const Name: string): Int128;
    procedure SetInt128(const Name: string; const Value: Int128);
    function GetUInt128(const Name: string): UInt128;
    procedure SetUInt128(const Name: string; const Value: UInt128);
    function GetString(const Name: string): string;
    procedure SetString(const Name, Value: string);
    function GetInt(const Name: string): integer;
    procedure SetInt(const Name: string; const Value: integer);
    function GetLong(const Name: string): int64;
    procedure SetLong(const Name: string; const Value: int64);
    function GetULong(const Name: string): uint64;
    procedure SetULong(const Name: string; const Value: uint64);
    function GetFloat(const Name: string): double;
    procedure SetFloat(const Name: string; const Value: double);
    function GetDateTime(const Name: string): TDateTime;
    procedure SetDateTime(const Name: string; const Value: TDateTime);
    function GetBool(const Name: string): boolean;
    procedure SetBool(const Name: string; const Value: boolean);
    function GetArray(const Name: string): TZ_JsonArray;
    function GetObject(const Name: string): TZ_JsonObject;

    property S[const Name: string]: string read GetString write SetString;
    property I[const Name: string]: integer read GetInt write SetInt;
    property I32[const Name: string]: integer read GetInt write SetInt;
    property L[const Name: string]: int64 read GetLong write SetLong;
    property I64[const Name: string]: int64 read GetLong write SetLong;
    property I128[const Name: string]: Int128 read GetInt128 write SetInt128;
    property U[const Name: string]: uint64 read GetULong write SetULong;
    property U64[const Name: string]: uint64 read GetULong write SetULong;
    property U128[const Name: string]: UInt128 read GetUInt128 write SetUInt128;
    property F[const Name: string]: double read GetFloat write SetFloat;
    property D[const Name: string]: TDateTime read GetDateTime write SetDateTime;
    property B[const Name: string]: boolean read GetBool write SetBool;
    property A[const Name: string]: TZ_JsonArray read GetArray;
    property O[const Name: string]: TZ_JsonObject read GetObject;

    function GetName(Index: integer): string;
    property Names[Index: integer]: string read GetName; default;
    function GetCount: integer;
    property Count: integer read GetCount;

    function Get_Default_S(const Name, Value: string): string;
    procedure Set_Default_S(const Name, Value: string);

    function GetDefault_S(const Name, Value: string): string;
    procedure SetDefault_S(const Name, Value: string);

    procedure SaveToStream(stream: TCore_Stream; Formated_: boolean); overload;
    procedure SaveToStream(stream: TCore_Stream); overload;
    procedure LoadFromStream(stream: TCore_Stream);
    procedure SaveToFile(FileName: SystemString);
    procedure LoadFromFile(FileName: SystemString);

    function GetMD5: TMD5;
    property MD5: TMD5 read GetMD5;

    function Parae(buff: TBytes): boolean;
    function ToBytes: TBytes;
    function ParseText(Text_: TZ_JsonString; UseUTF8: boolean): boolean; overload;
    function ParseText(Text_: TZ_JsonString): boolean; overload;

    function ToJSONString(Formated_: boolean): TZ_JsonString; overload;
    function ToJSONString: TZ_JsonString; overload;
    property ToJson: TZ_JsonString read ToJSONString;
    class procedure Test;
  end;

  TZ_JsonObject_List_Decl = TGenericsList<TZ_JsonObject>;

  TZ_JsonObject_List = class(TZ_JsonObject_List_Decl)
  public
    AutoFreeObj: boolean;
    constructor Create(AutoFreeObj_: boolean);
    destructor Destroy; override;
    function AddFromText(Text_: TZ_JsonString): TZ_JsonObject;
    function AddFromStream(stream: TCore_Stream): TZ_JsonObject;
    function AddFromFile(FileName: U_String): TZ_JsonObject;
    procedure Remove(obj: TZ_JsonObject);
    procedure Delete(Index: integer);
    procedure Clear;
    procedure Clean;
  end;

  TZJArry = TZ_JsonArray;
  TZJ = TZ_JsonObject;
  TZJList = TZ_JsonObject_List;
  TZJL = TZ_JsonObject_List;

implementation

{$IFDEF DELPHI}
{$I Z.Json_delphi.inc}
{$ELSE DELPHI}
{$I Z.Json_fpc.inc}
{$ENDIF DELPHI}


constructor TZ_JsonBase.Create(Parent_: TZ_JsonBase);
begin
  inherited Create;
  FParent := Parent_;
  if FParent <> nil then
      FParent.FList.Add(self);

  FList := TCore_ObjectList.Create;
  FList.AutoFreeObj := True;
end;

destructor TZ_JsonBase.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

constructor TZ_JsonArray.Create(Parent_: TZ_JsonBase);
begin
  inherited Create(Parent_);
end;

destructor TZ_JsonArray.Destroy;
begin
  inherited Destroy;
end;

procedure TZ_JsonArray.Add(const v_: Int128);
begin
  Add(v_.ToLString.Text);
end;

procedure TZ_JsonArray.Add(const v_: UInt128);
begin
  Add(v_.ToLString.Text);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: Int128);
begin
  Insert(Index, v_.ToLString.Text);
end;

procedure TZ_JsonArray.Insert(Index: integer; const v_: UInt128);
begin
  Insert(Index, v_.ToLString.Text);
end;

function TZ_JsonArray.GetInt128(Index: integer): Int128;
begin
  Result := Int128(TZ_JsonString(GetString(Index)).Text);
end;

procedure TZ_JsonArray.SetInt128(Index: integer; const Value: Int128);
begin
  SetString(Index, Value.ToLString.Text);
end;

function TZ_JsonArray.GetUInt128(Index: integer): UInt128;
begin
  Result := UInt128(TZ_JsonString(GetString(Index)).Text);
end;

procedure TZ_JsonArray.SetUInt128(Index: integer; const Value: UInt128);
begin
  SetString(Index, Value.ToLString.Text);
end;

constructor TZ_JsonObject.Create;
begin
  Create(nil);
end;

constructor TZ_JsonObject.Create(Parent_: TZ_JsonBase);
begin
  inherited Create(Parent_);
  FTag := 0;
  if Parent = nil then
      FInstance := TZ_Instance_JsonObject.Create;
end;

destructor TZ_JsonObject.Destroy;
begin
  if Parent = nil then
      FInstance.Free;
  inherited Destroy;
end;

procedure TZ_JsonObject.SwapInstance(source_: TZ_JsonObject);
var
  bak_FParent: TZ_JsonBase;
  bak_FList: TCore_ObjectList;
  bak_FInstance: TZ_Instance_JsonObject;
  bak_FTag: integer;
begin
  if FParent <> nil then
      raiseInfo('error.');
  bak_FParent := FParent;
  bak_FList := FList;
  bak_FInstance := FInstance;
  bak_FTag := FTag;

  FParent := source_.FParent;
  FList := source_.FList;
  FInstance := source_.FInstance;
  FTag := source_.FTag;

  source_.FParent := bak_FParent;
  source_.FList := bak_FList;
  source_.FInstance := bak_FInstance;
  source_.FTag := bak_FTag;
end;

procedure TZ_JsonObject.Assign(source_: TZ_JsonObject);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  source_.SaveToStream(m64);
  m64.Position := 0;
  LoadFromStream(m64);
  disposeObject(m64);
end;

function TZ_JsonObject.Clone: TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create;
  Result.Assign(self);
end;

function TZ_JsonObject.Exists(const Name: string): boolean;
begin
  Result := IndexOf(Name) >= 0;
end;

function TZ_JsonObject.GetInt128(const Name: string): Int128;
begin
  Result := Int128(TZ_JsonString(GetString(Name)).Text);
end;

procedure TZ_JsonObject.SetInt128(const Name: string; const Value: Int128);
begin
  SetString(Name, Value.ToLString);
end;

function TZ_JsonObject.GetUInt128(const Name: string): UInt128;
begin
  Result := UInt128(TZ_JsonString(GetString(Name)).Text);
end;

procedure TZ_JsonObject.SetUInt128(const Name: string; const Value: UInt128);
begin
  SetString(Name, Value.ToLString);
end;

function TZ_JsonObject.Get_Default_S(const Name, Value: string): string;
begin
  if Exists(Name) then
      Result := S[Name]
  else
      Result := Value;
end;

procedure TZ_JsonObject.Set_Default_S(const Name, Value: string);
begin
  S[Name] := Value;
end;

function TZ_JsonObject.GetDefault_S(const Name, Value: string): string;
begin
  if Exists(Name) then
      Result := S[Name]
  else
      Result := Value;
end;

procedure TZ_JsonObject.SetDefault_S(const Name, Value: string);
begin
  S[Name] := Value;
end;

procedure TZ_JsonObject.SaveToStream(stream: TCore_Stream);
begin
  SaveToStream(stream, True);
end;

procedure TZ_JsonObject.SaveToFile(FileName: SystemString);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  try
    SaveToStream(m64);
    m64.SaveToFile(FileName);
  finally
      disposeObject(m64);
  end;
end;

procedure TZ_JsonObject.LoadFromFile(FileName: SystemString);
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  try
      m64.LoadFromFile(FileName);
  except
    disposeObject(m64);
    Exit;
  end;

  try
      LoadFromStream(m64);
  finally
      disposeObject(m64);
  end;
end;

function TZ_JsonObject.GetMD5: TMD5;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  SaveToStream(m64, False);
  Result := umlStreamMD5(m64);
  disposeObject(m64);
end;

function TZ_JsonObject.Parae(buff: TBytes): boolean;
var
  m64: TMS64;
begin
  try
    m64 := TMS64.Create;
    m64.Mapping(@buff[0], length(buff));
    LoadFromStream(m64);
    disposeObject(m64);
    Result := True;
  except
      Result := False;
  end;
end;

function TZ_JsonObject.ToBytes: TBytes;
var
  m64: TMS64;
begin
  try
    m64 := TMS64.Create;
    SaveToStream(m64);
    Result := m64.ToBytes;
    disposeObject(m64);
  except
  end;
end;

function TZ_JsonObject.ParseText(Text_: TZ_JsonString; UseUTF8: boolean): boolean;
{$IFDEF FPC}
var j: TJSONData;
{$ENDIF FPC}
begin
  try
{$IFDEF FPC}
    DisposeObjectAndNil(FInstance);
    j := GetJSON(Text_.Text, UseUTF8);
    if Assigned(j) and (j is TZ_Instance_JsonObject) then
        FInstance := TZ_Instance_JsonObject(j)
    else
        FInstance := nil;
    Result := FInstance <> nil;
    if FInstance = nil then
        FInstance := TZ_Instance_JsonObject.Create;
{$ELSE FPC}
    if UseUTF8 then
        FInstance.FromUtf8JSON(Text_.Text)
    else
        FInstance.FromJSON(Text_.Text);
{$ENDIF FPC}
    Result := True;
  except
      Result := False;
  end;
end;

function TZ_JsonObject.ParseText(Text_: TZ_JsonString): boolean;
begin
  Result := ParseText(Text_, False);
end;

function TZ_JsonObject.ToJSONString(Formated_: boolean): TZ_JsonString;
begin
{$IFDEF FPC}
  if Formated_ then
      Result.Text := FInstance.FormatJSON([], 2)
  else
      Result.Text := FInstance.AsJSON;
{$ELSE}
  Result.Text := FInstance.ToJson(not Formated_);
{$ENDIF}
end;

function TZ_JsonObject.ToJSONString: TZ_JsonString;
begin
  Result := ToJSONString(True);
end;

class procedure TZ_JsonObject.Test;
var
  js: TZ_JsonObject;
  ii: integer;
  m64: TMS64;
begin
  js := TZ_JsonObject.Create();
  js.S['abc'] := '123';
  DoStatus(js.S['abc']);

  for ii := 1 to 3 do
      js.A['arry'].Add(ii);

  for ii := 0 to js.A['arry'].Count - 1 do
    begin
      DoStatus(js.A['arry'].I[ii]);
    end;

  js.A['arry'].AddObject.S['tt'] := 'inobj';

  js.O['obj'].S['fff'] := '999';

  DoStatus(js.ToJSONString(True));
  DoStatus('');
  DoStatus(js.O['obj'].ToJSONString(True));

  m64 := TMS64.Create;
  js.SaveToStream(m64);
  m64.Position := 0;
  js.O['obj'].LoadFromStream(m64);
  DoStatus(js.ToJSONString(True));
  js.Free;
end;

constructor TZ_JsonObject_List.Create(AutoFreeObj_: boolean);
begin
  inherited Create;
  AutoFreeObj := AutoFreeObj_;
end;

destructor TZ_JsonObject_List.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TZ_JsonObject_List.AddFromText(Text_: TZ_JsonString): TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create(nil);
  Result.ParseText(Text_);
  Add(Result);
end;

function TZ_JsonObject_List.AddFromStream(stream: TCore_Stream): TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create(nil);
  Result.LoadFromStream(stream);
  Add(Result);
end;

function TZ_JsonObject_List.AddFromFile(FileName: U_String): TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create(nil);
  Result.LoadFromFile(FileName);
  Add(Result);
end;

procedure TZ_JsonObject_List.Remove(obj: TZ_JsonObject);
begin
  if AutoFreeObj then
      disposeObject(obj);
  inherited Remove(obj);
end;

procedure TZ_JsonObject_List.Delete(Index: integer);
begin
  if (Index >= 0) and (Index < Count) then
    begin
      if AutoFreeObj then
          disposeObject(Items[Index]);
      inherited Delete(Index);
    end;
end;

procedure TZ_JsonObject_List.Clear;
var
  I: integer;
begin
  if AutoFreeObj then
    for I := 0 to Count - 1 do
        disposeObject(Items[I]);
  inherited Clear;
end;

procedure TZ_JsonObject_List.Clean;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
      disposeObject(Items[I]);
  inherited Clear;
end;

initialization

end.
 
