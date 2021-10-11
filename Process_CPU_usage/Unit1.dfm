object Form1: TForm1
  Left = 244
  Top = 127
  Width = 385
  Height = 501
  Caption = 'Process CPU usage'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  OnCreate = FormCreate
  DesignSize = (
    377
    473)
  PixelsPerInch = 120
  TextHeight = 16
  object ListView1: TListView
    Left = 8
    Top = 8
    Width = 361
    Height = 457
    Anchors = [akLeft, akTop, akRight, akBottom]
    Columns = <
      item
        Caption = 'Process'
        Width = 185
      end
      item
        Alignment = taRightJustify
        Caption = 'PID'
        Width = 74
      end
      item
        Alignment = taRightJustify
        Caption = 'CPU'
        Width = 74
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnCustomDrawItem = ListView1CustomDrawItem
  end
  object Button1: TButton
    Left = -123
    Top = 373
    Width = 92
    Height = 31
    Caption = 'Button1'
    TabOrder = 0
  end
  object XPManifest1: TXPManifest
    Left = 55
    Top = 46
  end
  object Timer1: TTimer
    Enabled = False
    OnTimer = Timer1Timer
    Left = 17
    Top = 46
  end
end
