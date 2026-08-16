# Z.Geometry.Low 完整 API 参考手册

> 本手册以表格形式列出 `Z.Geometry.Low` 单元的全部导出成员，按类别分组：**类型定义**、**常量**、**向量函数**、**矩阵函数**、**平面函数**、**四元数函数**、**插值与缓动函数**、**三角函数与数学工具**、**几何相交测试**、**坐标变换**、**杂项工具**。每个条目均附有说明。

---

## 目录

- [1. 类型定义](#1-类型定义)
- [2. 常量](#2-常量)
- [3. 向量函数](#3-向量函数)
  - [3.1 构造与设置](#31-构造与设置)
  - [3.2 基本算术运算](#32-基本算术运算)
  - [3.3 点积 / 叉积 / 投影](#33-点积--叉积--投影)
  - [3.4 长度 / 范数 / 归一化](#34-长度--范数--归一化)
  - [3.5 比较与判定](#35-比较与判定)
  - [3.6 缩放 / 取反 / 取绝对值](#36-缩放--取反--取绝对值)
  - [3.7 旋转](#37-旋转)
  - [3.8 数组批量操作](#38-数组批量操作)
- [4. 矩阵函数](#4-矩阵函数)
  - [4.1 构造与设置](#41-构造与设置)
  - [4.2 矩阵运算](#42-矩阵运算)
  - [4.3 变换与视图矩阵](#43-变换与视图矩阵)
  - [4.4 矩阵分解与打包](#44-矩阵分解与打包)
- [5. 平面函数](#5-平面函数)
- [6. 四元数函数](#6-四元数函数)
- [7. 插值与缓动函数](#7-插值与缓动函数)
- [8. 三角函数与数学工具](#8-三角函数与数学工具)
- [9. 几何相交测试](#9-几何相交测试)
- [10. 坐标变换（Turn / Pitch / Roll）](#10-坐标变换turn--pitch--roll)
- [11. 杂项工具](#11-杂项工具)

---

## 1. 类型定义

### 1.1 向量类型

| 类型名 | 定义 | 说明 |
| :--- | :--- | :--- |
| `TVector2f` | `array[0..1] of TGeoFloat` | 2 分量浮点向量 (x, y) |
| `TVector3f` | `array[0..2] of TGeoFloat` | 3 分量浮点向量 (x, y, z) |
| `TVector4f` | `array[0..3] of TGeoFloat` | 4 分量浮点向量 (x, y, z, w) |
| `TVector4i` | `array[0..3] of Integer` | 4 分量整数向量（用于视口等） |
| `TAffineFltVector` | `TVector3f` | 仿射向量别名 |
| `TAffineVector` | `TVector3f` | 仿射向量（3D 点/方向） |
| `THomogeneousFltVector` | `TVector4f` | 齐次向量别名 |
| `TVector` | `THomogeneousFltVector` | 齐次向量（4D，w 表示方向/点） |
| `THomogeneousVector` | `THomogeneousFltVector` | 同 `TVector` |
| `TVertex` | `TAffineVector` | 顶点别名 |

### 1.2 矩阵类型

| 类型名 | 定义 | 说明 |
| :--- | :--- | :--- |
| `TMatrix2f` | `array[0..1] of TVector2f` | 2×2 矩阵 |
| `TMatrix3f` | `array[0..2] of TVector3f` | 3×3 仿射矩阵 |
| `TMatrix4f` | `array[0..3] of TVector4f` | 4×4 齐次矩阵 |
| `TAffineFltMatrix` | `TMatrix3f` | 仿射矩阵别名 |
| `TAffineMatrix` | `TAffineFltMatrix` | 3×3 仿射变换矩阵 |
| `THomogeneousFltMatrix` | `TMatrix4f` | 齐次矩阵别名 |
| `TMatrix` | `THomogeneousFltMatrix` | 4×4 齐次变换矩阵 |

### 1.3 指针类型

| 类型名 | 定义 | 说明 |
| :--- | :--- | :--- |
| `PFloat` | `^Single` | 单精度浮点指针 |
| `PTexPoint` | `^TTexPoint` | 纹理坐标指针 |
| `PFloatVector` | `^TFloatVector` | 浮点流指针 |
| `PFloatArray` | `PFloatVector` | 浮点数组指针 |
| `PSingleArray` | `PFloatArray` | 单精度数组指针 |
| `PDoubleVector` | `^TDoubleVector` | 双精度流指针 |
| `PDoubleArray` | `PDoubleVector` | 双精度数组指针 |
| `PVector2f` | `^TVector2f` | 2D 向量指针 |
| `PVector` | `^TVector` | 齐次向量指针 |
| `PHomogeneousVector` | `^THomogeneousVector` | 齐次向量指针 |
| `PAffineVector` | `^TAffineVector` | 仿射向量指针 |
| `PVertex` | `^TVertex` | 顶点指针 |
| `PMatrix` | `^TMatrix` | 齐次矩阵指针 |
| `PAffineMatrix` | `^TAffineMatrix` | 仿射矩阵指针 |
| `PQuaternion` | `^TQuaternion` | 四元数指针 |
| `PHomogeneousFltVector` | `^THomogeneousFltVector` | 齐次向量指针 |
| `PAffineFltVector` | `^TAffineFltVector` | 仿射向量指针 |

### 1.4 数组类型

| 类型名 | 定义 | 说明 |
| :--- | :--- | :--- |
| `TFloatVector` | `array[0..MaxInt div SizeOf(TGeoFloat)-1] of TGeoFloat` | 连续浮点流 |
| `TSingleArray` | `array of TGeoFloat` | 单精度动态数组 |
| `TDoubleVector` | `array[0..MaxInt div SizeOf(Double)-1] of Double` | 连续双精度流 |
| `TDdoubleArray` | `array of Double` | 双精度动态数组 |
| `TAffineVectorArray` | `array[0..MaxInt div SizeOf(TAffineVector)-1] of TAffineVector` | 仿射向量数组 |
| `TVectorArray` | `array[0..MaxInt div SizeOf(TVector)-1] of TVector` | 齐次向量数组 |
| `TTexPointArray` | `array[0..MaxInt div SizeOf(TTexPoint)-1] of TTexPoint` | 纹理坐标数组 |
| `TMatrixArray` | `array[0..MaxInt div SizeOf(TMatrix)-1] of TMatrix` | 齐次矩阵数组 |
| `TQuaternionArray` | `array[0..MaxInt div SizeOf(TQuaternion)-1] of TQuaternion` | 四元数数组 |
| `PAffineVectorArray` | `^TAffineVectorArray` | 仿射向量数组指针 |
| `PVectorArray` | `^TVectorArray` | 齐次向量数组指针 |
| `PTexPointArray` | `^TTexPointArray` | 纹理坐标数组指针 |
| `PMatrixArray` | `^TMatrixArray` | 齐次矩阵数组指针 |
| `PQuaternionArray` | `^TQuaternionArray` | 四元数数组指针 |

### 1.5 记录与枚举类型

| 类型名 | 定义 | 说明 |
| :--- | :--- | :--- |
| `TTexPoint` | `record s,t: TGeoFloat` | 2D 纹理坐标 (s, t) |
| `TQuaternion` | `record ImagPart: TAffineVector; RealPart: TGeoFloat` | 四元数（虚部 xyz，实部 w） |
| `TRectangle` | `record Left,Top,width,height: Integer` | 整数矩形 |
| `TFrustum` | `record pLeft,pTop,pRight,pBottom,pNear,pFar: THmgPlane` | 视锥体六裁剪面 |
| `TTransType` | 枚举 | 变换类型（缩放/剪切/旋转/平移/透视） |
| `TTransformations` | `array[TTransType] of TGeoFloat` | 变换参数数组（用于矩阵分解） |
| `TPackedRotationMatrix` | `array[0..2] of SmallInt` | 压缩旋转矩阵（6 字节） |
| `TEulerOrder` | 枚举 | 欧拉角顺序（XYZ, XZY, YXZ, YZX, ZXY, ZYX） |
| `TGLInterpolationType` | 枚举 | 插值类型（Linear, Power, Sin, SinAlt, Tan, Ln, Exp） |

---

## 2. 常量

### 2.1 纹理坐标常量

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `XTexPoint` | `(s=1, t=0)` | 纹理坐标 (1,0) |
| `YTexPoint` | `(s=0, t=1)` | 纹理坐标 (0,1) |
| `XYTexPoint` | `(s=1, t=1)` | 纹理坐标 (1,1) |
| `NullTexPoint` | `(s=0, t=0)` | 纹理坐标 (0,0) |
| `MidTexPoint` | `(s=0.5, t=0.5)` | 纹理坐标 (0.5,0.5) |

### 2.2 标准 3D 轴向量

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `XVector` | `(1,0,0)` | X 轴单位向量 |
| `YVector` | `(0,1,0)` | Y 轴单位向量 |
| `ZVector` | `(0,0,1)` | Z 轴单位向量 |
| `XYVector` | `(1,1,0)` | XY 平面对角线 |
| `XZVector` | `(1,0,1)` | XZ 平面对角线 |
| `YZVector` | `(0,1,1)` | YZ 平面对角线 |
| `XYZVector` | `(1,1,1)` | 空间对角线 |
| `NullVector` | `(0,0,0)` | 零向量 |
| `MinusXVector` | `(-1,0,0)` | X 轴负方向 |
| `MinusYVector` | `(0,-1,0)` | Y 轴负方向 |
| `MinusZVector` | `(0,0,-1)` | Z 轴负方向 |

### 2.3 标准齐次向量（方向，w=0）

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `XHmgVector` | `(1,0,0,0)` | X 方向齐次向量 |
| `YHmgVector` | `(0,1,0,0)` | Y 方向齐次向量 |
| `ZHmgVector` | `(0,0,1,0)` | Z 方向齐次向量 |
| `WHmgVector` | `(0,0,0,1)` | W 方向齐次向量 |
| `XYHmgVector` | `(1,1,0,0)` | XY 齐次向量 |
| `YZHmgVector` | `(0,1,1,0)` | YZ 齐次向量 |
| `XZHmgVector` | `(1,0,1,0)` | XZ 齐次向量 |
| `XYZHmgVector` | `(1,1,1,0)` | XYZ 齐次向量 |
| `XYZWHmgVector` | `(1,1,1,1)` | 全 1 齐次向量 |
| `NullHmgVector` | `(0,0,0,0)` | 零齐次向量 |

### 2.4 标准齐次点（w=1）

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `XHmgPoint` | `(1,0,0,1)` | X 轴上的点 |
| `YHmgPoint` | `(0,1,0,1)` | Y 轴上的点 |
| `ZHmgPoint` | `(0,0,1,1)` | Z 轴上的点 |
| `WHmgPoint` | `(0,0,0,1)` | 原点 |
| `NullHmgPoint` | `(0,0,0,1)` | 原点 |

### 2.5 矩阵常量

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `IdentityMatrix` | 3×3 单位矩阵 | 仿射单位矩阵 |
| `IdentityHmgMatrix` | 4×4 单位矩阵 | 齐次单位矩阵 |
| `EmptyMatrix` | 3×3 零矩阵 | 全零仿射矩阵 |
| `EmptyHmgMatrix` | 4×4 零矩阵 | 全零齐次矩阵 |

### 2.6 四元数常量

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `IdentityQuaternion` | `(0,0,0,1)` | 单位四元数（无旋转） |

### 2.7 数学常量

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `Epsilon` | `1E-40` | 极小容差值 |
| `EPSILON2` | `1E-30` | 常用容差值 |
| `cPI` | `3.141592654` | π |
| `cPIdiv180` | `0.017453292` | π/180（度转弧度） |
| `c180divPI` | `57.29577951` | 180/π（弧度转度） |
| `c2PI` | `6.283185307` | 2π |
| `cPIdiv2` | `1.570796326` | π/2 |
| `cPIdiv4` | `0.785398163` | π/4 |
| `c3PIdiv2` | `4.71238898` | 3π/2 |
| `c3PIdiv4` | `2.35619449` | 3π/4 |
| `cInv2PI` | `1/(2π)` | 2π 的倒数 |
| `cInv360` | `1/360` | 360 的倒数 |
| `c180` | `180` | 180 度 |
| `c360` | `360` | 360 度 |
| `cOneHalf` | `0.5` | 1/2 |
| `cLn10` | `2.302585093` | ln(10) |

### 2.8 IEEE 浮点范围

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `MinSingle` | `1.5E-45` | 最小单精度正数 |
| `MaxSingle` | `3.4E+38` | 最大单精度正数 |
| `MinDouble` | `5.0E-324` | 最小双精度正数 |
| `MaxDouble` | `1.7E+308` | 最大双精度正数 |
| `MinComp` | `-9.223372036854775807E+18` | 最小 Comp 值 |
| `MaxComp` | `9.223372036854775807E+18` | 最大 Comp 值 |
| `CColinearBias` | `1E-8` | 共线判定容差 |
| `cZero` | `0.0` | 零 |
| `cOne` | `1.0` | 一 |
| `cOneDotFive` | `0.5` | 0.5 |
| `cEpsilon` | `1E-10` | 小容差 |

---

## 3. 向量函数

### 3.1 构造与设置

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `TexPointMake` | `s,t: TGeoFloat` | `TTexPoint` | 创建纹理坐标 |
| `AffineVectorMake` | `x,y,z: TGeoFloat` | `TAffineVector` | 从三个分量创建仿射向量 |
| `AffineVectorMake` | `v: TVector` | `TAffineVector` | 从齐次向量提取 3D 部分 |
| `SetAffineVector` | `out v; x,y,z` | - | 设置仿射向量分量 |
| `SetVector` | `out v: TAffineVector; x,y,z` | - | 设置仿射向量分量 |
| `SetVector` | `out v: TAffineVector; vSrc: TVector` | - | 从齐次向量复制 3D 部分 |
| `SetVector` | `out v: TAffineVector; vSrc: TAffineVector` | - | 复制仿射向量 |
| `VectorMake` | `v: TAffineVector; w: TGeoFloat = 0` | `TVector` | 从仿射向量创建齐次向量 |
| `VectorMake` | `x,y,z: TGeoFloat; w: TGeoFloat = 0` | `TVector` | 从分量创建齐次向量 |
| `PointMake` | `x,y,z: TGeoFloat` | `TVector` | 创建齐次点（w=1） |
| `PointMake` | `v: TAffineVector` | `TVector` | 从仿射向量创建齐次点 |
| `PointMake` | `v: TVector` | `TVector` | 将齐次向量转为齐次点 |
| `SetVector` | `out v: TVector; x,y,z; w=0` | - | 设置齐次向量分量 |
| `SetVector` | `out v: TVector; av: TAffineVector; w=0` | - | 从仿射向量设置齐次向量 |
| `SetVector` | `out v: TVector; vSrc: TVector` | - | 复制齐次向量 |
| `MakePoint` | `out v: TVector; x,y,z` | - | 设置齐次点（w=1） |
| `MakePoint` | `out v: TVector; av: TAffineVector` | - | 从仿射向量设置齐次点 |
| `MakePoint` | `out v: TVector; av: TVector` | - | 从齐次向量设置齐次点（w=1） |
| `MakeVector` | `out v: TAffineVector; x,y,z` | - | 设置仿射向量 |
| `MakeVector` | `out v: TVector; x,y,z` | - | 设置齐次方向（w=0） |
| `MakeVector` | `out v: TVector; av: TAffineVector` | - | 从仿射向量设置齐次方向 |
| `MakeVector` | `out v: TVector; av: TVector` | - | 复制齐次方向（w=0） |
| `RstVector` | `var v: TAffineVector` | - | 仿射向量置零 |
| `RstVector` | `var v: TVector` | - | 齐次向量置零 |
| `Vector2fMake` | `x,y: TGeoFloat` | `TVector2f` | 创建 2D 向量 |
| `Vector2fMake` | `Vector: TVector3f` | `TVector2f` | 从 3D 向量取前两分量 |
| `Vector2fMake` | `Vector: TVector4f` | `TVector2f` | 从 4D 向量取前两分量 |
| `Vector3fMake` | `x: TGeoFloat; y=0; z=0` | `TVector3f` | 创建 3D 向量（带默认值） |
| `Vector3fMake` | `Vector: TVector2f; z=0` | `TVector3f` | 从 2D 创建 3D（z 默认 0） |
| `Vector3fMake` | `Vector: TVector4f` | `TVector3f` | 从 4D 取前三分量 |
| `Vector4fMake` | `x,y,z,w: TGeoFloat` | `TVector4f` | 创建 4D 向量 |
| `Vector4fMake` | `Vector: TVector3f; w=0` | `TVector4f` | 从 3D 创建 4D（w 默认 0） |
| `Vector4fMake` | `Vector: TVector2f; z=0; w=0` | `TVector4f` | 从 2D 创建 4D |

### 3.2 基本算术运算

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorAdd` (2f) | `v1,v2: TVector2f` | `TVector2f` | 2D 向量加法 |
| `VectorAdd` (affine) | `v1,v2: TAffineVector` | `TAffineVector` | 3D 向量加法 |
| `VectorAdd` (proc) | `v1,v2: TAffineVector; var vr` | - | 3D 向量加法，结果存放 |
| `VectorAdd` (proc, ptr) | `v1,v2: TAffineVector; vr: PAffineVector` | - | 同上，指针形式 |
| `VectorAdd` (hmg) | `v1,v2: TVector` | `TVector` | 齐次向量加法 |
| `VectorAdd` (hmg proc) | `v1,v2: TVector; var vr` | - | 齐次加法，结果存放 |
| `VectorAdd` (affine+scalar) | `v: TAffineVector; f` | `TAffineVector` | 向量各分量加标量 |
| `VectorAdd` (hmg+scalar) | `v: TVector; f` | `TVector` | 齐次各分量加标量 |
| `AddVector` (aff+aff) | `var v1: TAffineVector; v2: TAffineVector` | - | 就地加法 |
| `AddVector` (aff+hmg) | `var v1: TAffineVector; v2: TVector` | - | 就地加法（用 v2 前 3 分量） |
| `AddVector` (hmg+hmg) | `var v1: TVector; v2: TVector` | - | 就地齐次加法 |
| `AddVector` (aff+scalar) | `var v: TAffineVector; f` | - | 就地标量加法 |
| `AddVector` (hmg+scalar) | `var v: TVector; f` | - | 就地齐次标量加法 |
| `AddPoint` | `var v1: TVector; v2: TVector` | - | 齐次点加法（w 保持 1） |
| `PointAdd` | `var v1: TVector; v2: TVector` | `TVector` | 齐次点加法返回新点 |
| `VectorSubtract` (2f) | `v1,v2: TVector2f` | `TVector2f` | 2D 向量减法 |
| `SubtractVector` (2f) | `var v1; v2: TVector2f` | - | 就地 2D 减法 |
| `VectorSubtract` (aff) | `v1,v2: TAffineVector` | `TAffineVector` | 3D 向量减法 |
| `VectorSubtract` (aff proc) | `v1,v2: TAffineVector; var Result` | - | 3D 减法结果存放 |
| `VectorSubtract` (aff→hmg) | `v1,v2: TAffineVector; var Result: TVector` | - | 减法结果放入齐次向量（w=0） |
| `VectorSubtract` (hmg→aff) | `v1: TVector; v2: TAffineVector; var Result: TVector` | - | 齐次-仿射，结果齐次 |
| `VectorSubtract` (hmg) | `v1,v2: TVector` | `TVector` | 齐次向量减法 |
| `VectorSubtract` (hmg proc) | `v1,v2: TVector; var Result` | - | 齐次减法结果存放 |
| `VectorSubtract` (hmg→aff) | `v1,v2: TVector; var Result: TAffineVector` | - | 齐次减法只保留 3D |
| `VectorSubtract` (aff-scalar) | `v1: TAffineVector; Delta` | `TAffineVector` | 各分量减标量 |
| `VectorSubtract` (hmg-scalar) | `v1: TVector; Delta` | `TVector` | 齐次各分量减标量 |
| `SubtractVector` (aff) | `var v1: TAffineVector; v2: TAffineVector` | - | 就地减法 |
| `SubtractVector` (hmg) | `var v1: TVector; v2: TVector` | - | 就地齐次减法 |
| `VectorCombine` (aff) | `v1,v2; f1,f2` | `TAffineVector` | 线性组合 f1*v1 + f2*v2 |
| `VectorCombine` (hmg) | `v1,v2; f1,f2` | `TVector` | 齐次线性组合 |
| `VectorCombine3` (aff) | `v1,v2,v3; f1,f2,f3` | `TAffineVector` | 三个向量线性组合 |
| `VectorCombine3` (hmg) | `v1,v2,v3; f1,f2,f3` | `TVector` | 三个齐次向量线性组合 |
| `CombineVector` (aff) | `var vr; v; var f` | - | 就地 vr += v*f |
| `CombineVector` (hmg) | `var vr: TVector; v: TVector; var f` | - | 就地齐次线性组合 |
| `TexPointCombine` | `t1,t2; f1,f2` | `TTexPoint` | 纹理坐标线性组合 |

### 3.3 点积 / 叉积 / 投影

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorDotProduct` (2f) | `v1,v2: TVector2f` | `TGeoFloat` | 2D 点积 |
| `VectorDotProduct` (aff) | `v1,v2: TAffineVector` | `TGeoFloat` | 3D 点积 |
| `VectorDotProduct` (hmg) | `v1,v2: TVector` | `TGeoFloat` | 齐次点积（含 w） |
| `VectorDotProduct` (hmg×aff) | `v1: TVector; v2: TAffineVector` | `TGeoFloat` | 齐次前 3 分量与仿射点积 |
| `VectorCrossProduct` (aff) | `v1,v2: TAffineVector` | `TAffineVector` | 3D 叉积 |
| `VectorCrossProduct` (hmg) | `v1,v2: TVector` | `TVector` | 齐次叉积（w=0） |
| `VectorCrossProduct` (hmg proc) | `v1,v2: TVector; var vr` | - | 齐次叉积结果存放 |
| `VectorCrossProduct` (aff→hmg) | `v1,v2: TAffineVector; var vr: TVector` | - | 叉积放入齐次（w=0） |
| `VectorCrossProduct` (hmg→aff) | `v1,v2: TVector; var vr: TAffineVector` | - | 叉积只保留 3D |
| `VectorCrossProduct` (aff proc) | `v1,v2: TAffineVector; var vr: TAffineVector` | - | 叉积结果存放 |
| `PointProject` (aff) | `p, origin, direction` | `TGeoFloat` | 投影距离 (p-origin)·direction |
| `PointProject` (hmg) | `p, origin, direction` | `TGeoFloat` | 同上，齐次版本 |

### 3.4 长度 / 范数 / 归一化

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorLength` (x,y) | `x,y: TGeoFloat` | `TGeoFloat` | sqrt(x²+y²) |
| `VectorLength` (x,y,z) | `x,y,z: TGeoFloat` | `TGeoFloat` | sqrt(x²+y²+z²) |
| `VectorLength` (2f) | `v: TVector2f` | `TGeoFloat` | 2D 长度 |
| `VectorLength` (aff) | `v: TAffineVector` | `TGeoFloat` | 3D 长度 |
| `VectorLength` (hmg) | `v: TVector` | `TGeoFloat` | 3D 长度（忽略 w） |
| `VectorLength` (array) | `v: array of TGeoFloat` | `TGeoFloat` | 任意维长度 |
| `VectorNorm` (x,y) | `x,y: TGeoFloat` | `TGeoFloat` | x²+y² |
| `VectorNorm` (aff) | `v: TAffineVector` | `TGeoFloat` | 范数（平方长度） |
| `VectorNorm` (hmg) | `v: TVector` | `TGeoFloat` | 忽略 w 的范数 |
| `VectorNorm` (array) | `var v: array of TGeoFloat` | `TGeoFloat` | 任意维范数 |
| `NormalizeVector` (2f) | `var v: TVector2f` | - | 就地归一化 |
| `NormalizeVector` (aff) | `var v: TAffineVector` | - | 就地归一化 |
| `NormalizeVector` (hmg) | `var v: TVector` | - | 就地归一化（w=0） |
| `VectorNormalize` (2f) | `v: TVector2f` | `TVector2f` | 返回归一化向量 |
| `VectorNormalize` (aff) | `v: TAffineVector` | `TAffineVector` | 返回归一化向量 |
| `VectorNormalize` (hmg) | `v: TVector` | `TVector` | 返回归一化齐次向量（w=0） |

### 3.5 比较与判定

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorEquals` (2f) | `v1,v2: TVector2f` | `Boolean` | 2D 向量相等 |
| `VectorEquals` (aff) | `v1,v2: TAffineVector` | `Boolean` | 3D 向量相等 |
| `VectorEquals` (hmg) | `v1,v2: TVector` | `Boolean` | 齐次向量相等 |
| `AffineVectorEquals` | `v1,v2: TVector` | `Boolean` | 仅比较前 3 分量 |
| `VectorIsNull` (aff) | `v: TAffineVector` | `Boolean` | 是否零向量 |
| `VectorIsNull` (hmg) | `v: TVector` | `Boolean` | 是否零向量（忽略 w） |
| `TexpointEquals` | `p1,p2: TTexPoint` | `Boolean` | 纹理坐标相等 |
| `IsColinear` (2f) | `v1,v2: TVector2f` | `Boolean` | 是否共线 |
| `IsColinear` (aff) | `v1,v2: TAffineVector` | `Boolean` | 是否共线 |
| `IsColinear` (hmg) | `v1,v2: TVector` | `Boolean` | 是否共线（忽略 w） |
| `VectorMoreThen` (3f/4f) | 向量 vs 向量 | `Boolean` | 所有分量大于 |
| `VectorMoreEqualThen` | 向量 vs 向量 | `Boolean` | 所有分量大于等于 |
| `VectorLessThen` | 向量 vs 向量 | `Boolean` | 所有分量小于 |
| `VectorLessEqualThen` | 向量 vs 向量 | `Boolean` | 所有分量小于等于 |
| （均有标量版本） | 向量 vs 标量 | `Boolean` | 同上 |

### 3.6 缩放 / 取反 / 取绝对值

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorScale` (2f) | `v,factor` | `TVector2f` | 2D 向量缩放 |
| `VectorScale` (aff) | `v,factor` | `TAffineVector` | 3D 向量缩放 |
| `VectorScale` (hmg) | `v,factor` | `TVector` | 齐次向量缩放 |
| `VectorScale` (aff, v factor) | `v,factor: TAffineVector` | `TAffineVector` | 分量乘法缩放 |
| `VectorScale` (hmg, v factor) | `v,factor: TVector` | `TVector` | 齐次分量乘法缩放 |
| `ScaleVector` (2f) | `var v; factor` | - | 就地 2D 缩放 |
| `ScaleVector` (aff) | `var v; factor` | - | 就地 3D 缩放 |
| `ScaleVector` (hmg) | `var v; factor` | - | 就地齐次缩放 |
| `ScaleVector` (aff vector) | `var v; factor: TAffineVector` | - | 就地分量乘法 |
| `ScaleVector` (hmg vector) | `var v; factor: TVector` | - | 就地齐次分量乘法 |
| `VectorDivide` (hmg) | `v, divider` | `TVector` | 分量除法 |
| `VectorDivide` (aff) | `v, divider` | `TAffineVector` | 分量除法 |
| `DivideVector` (hmg) | `var v; divider` | - | 就地分量除法 |
| `DivideVector` (aff) | `var v; divider` | - | 就地分量除法 |
| `VectorNegate` (aff) | `v` | `TAffineVector` | 返回取反向量 |
| `VectorNegate` (hmg) | `v` | `TVector` | 返回取反齐次向量 |
| `NegateVector` (aff) | `var v` | - | 就地取反 |
| `NegateVector` (hmg) | `var v` | - | 就地齐次取反 |
| `NegateVector` (array) | `var v: array of TGeoFloat` | - | 任意数组取反 |
| `VectorAbs` (aff) | `v` | `TAffineVector` | 返回绝对值向量 |
| `VectorAbs` (hmg) | `v` | `TVector` | 返回绝对值齐次向量 |
| `AbsVector` (aff) | `var v` | - | 就地取绝对值 |
| `AbsVector` (hmg) | `var v` | - | 就地齐次取绝对值 |

### 3.7 旋转

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `RotateVector` | `var Vector: TVector; axis: TAffineVector; angle` | - | 绕轴旋转齐次向量（弧度） |
| `RotateVector` | `var Vector: TVector; axis: TVector; angle` | - | 同上，轴为齐次 |
| `RotateVectorAroundY` | `var v: TAffineVector; alpha` | - | 绕 Y 轴旋转（就地） |
| `VectorRotateAroundX` | `v: TAffineVector; alpha` | `TAffineVector` | 绕 X 轴旋转返回 |
| `VectorRotateAroundY` | `v: TAffineVector; alpha` | `TAffineVector` | 绕 Y 轴旋转返回 |
| `VectorRotateAroundY` (proc) | `v; alpha; var vr` | - | 绕 Y 轴旋转结果存放 |
| `VectorRotateAroundZ` | `v: TAffineVector; alpha` | `TAffineVector` | 绕 Z 轴旋转返回 |

### 3.8 数组批量操作

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorArrayAdd` | `Src, Delta, nb, dest` | - | 将 Delta 加到每个向量 |
| `VectorArrayLerp` (hmg) | `src1,src2,t,n,dest` | - | 批量线性插值（齐次） |
| `VectorArrayLerp` (aff) | `src1,src2,t,n,dest` | - | 批量线性插值（仿射） |
| `VectorArrayLerp` (texpoint) | `src1,src2,t,n,dest` | - | 批量纹理坐标插值 |
| `NormalizeVectorArray` | `List,n` | - | 批量归一化 |
| `TexPointArrayAdd` | `Src, Delta, nb, dest` | - | 批量纹理坐标加法 |
| `TexPointArrayScaleAndAdd` | `Src, Delta, nb, Scale, dest` | - | 缩放并加 Delta |
| `ScaleFloatArray` (raw) | `values,nb,factor` | - | 批量浮点数缩放 |
| `ScaleFloatArray` (array) | `var values; factor` | - | 批量缩放 |
| `OffsetFloatArray` (raw) | `values,nb,Delta` | - | 批量加 Delta |
| `OffsetFloatArray` (array) | `var values; Delta` | - | 批量加 Delta |
| `OffsetFloatArray` (dest+delta) | `valuesDest,valuesDelta,nb` | - | 目标 += 增量 |

---

## 4. 矩阵函数

### 4.1 构造与设置

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `SetMatrix` | `var dest: TAffineMatrix; Src: TMatrix` | - | 从齐次矩阵复制 3×3 部分 |
| `SetMatrix` | `var dest: TMatrix; Src: TAffineMatrix` | - | 从仿射矩阵扩展为齐次矩阵 |
| `SetMatrixRow` | `var dest: TMatrix; rowNb; aRow` | - | 设置矩阵某一行 |
| `CreateScaleMatrix` | `v: TAffineVector` | `TMatrix` | 创建缩放矩阵 |
| `CreateScaleMatrix` | `v: TVector` | `TMatrix` | 创建缩放矩阵（齐次） |
| `CreateTranslationMatrix` | `v: TAffineVector` | `TMatrix` | 创建平移矩阵 |
| `CreateTranslationMatrix` | `v: TVector` | `TMatrix` | 创建平移矩阵（齐次） |
| `CreateScaleAndTranslationMatrix` | `Scale, Offset: TVector` | `TMatrix` | 先缩放后平移 |
| `CreateRotationMatrixX` | `sine, cosine` | `TMatrix` | 用 sin/cos 创建 X 旋转矩阵 |
| `CreateRotationMatrixX` | `angle` | `TMatrix` | 绕 X 轴旋转矩阵（弧度） |
| `CreateRotationMatrixY` | `sine, cosine` / `angle` | `TMatrix` | 绕 Y 轴旋转矩阵 |
| `CreateRotationMatrixZ` | `sine, cosine` / `angle` | `TMatrix` | 绕 Z 轴旋转矩阵 |
| `CreateRotationMatrix` | `anAxis: TAffineVector; angle` | `TMatrix` | 绕任意轴旋转矩阵 |
| `CreateRotationMatrix` | `anAxis: TVector; angle` | `TMatrix` | 同上，轴为齐次 |
| `CreateAffineRotationMatrix` | `anAxis: TAffineVector; angle` | `TAffineMatrix` | 仿射旋转矩阵 |

### 4.2 矩阵运算

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `MatrixMultiply` (aff) | `m1,m2: TAffineMatrix` | `TAffineMatrix` | 3×3 矩阵乘法 |
| `MatrixMultiply` (hmg) | `m1,m2: TMatrix` | `TMatrix` | 4×4 矩阵乘法 |
| `MatrixMultiply` (proc) | `m1,m2; var MResult` | - | 4×4 乘法结果存放 |
| `MatrixDeterminant` (aff) | `M: TAffineMatrix` | `TGeoFloat` | 3×3 行列式 |
| `MatrixDeterminant` (hmg) | `M: TMatrix` | `TGeoFloat` | 4×4 行列式 |
| `AdjointMatrix` (hmg) | `var M: TMatrix` | - | 计算伴随矩阵 |
| `AdjointMatrix` (aff) | `var M: TAffineMatrix` | - | 3×3 伴随矩阵 |
| `ScaleMatrix` (aff) | `var M; factor` | - | 矩阵所有元素乘以因子 |
| `ScaleMatrix` (hmg) | `var M; factor` | - | 齐次矩阵所有元素乘以因子 |
| `TransposeMatrix` (aff) | `var M` | - | 转置 3×3 |
| `TransposeMatrix` (hmg) | `var M` | - | 转置 4×4 |
| `InvertMatrix` (hmg) | `var M` | - | 就地求逆（奇异则置单位阵） |
| `MatrixInvert` (hmg) | `M` | `TMatrix` | 返回逆矩阵 |
| `InvertMatrix` (aff) | `var M` | - | 就地 3×3 求逆 |
| `MatrixInvert` (aff) | `M` | `TAffineMatrix` | 返回 3×3 逆 |
| `AnglePreservingMatrixInvert` | `mat: TMatrix` | `TMatrix` | 角度保持矩阵快速逆 |
| `transpose_scale_m33` | `Src; var dest; var Scale` | - | 转置并缩放 3×3 子矩阵 |

### 4.3 变换与视图矩阵

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorTransform` (hmg×hmg) | `v: TVector; M: TMatrix` | `TVector` | 齐次向量乘以矩阵 |
| `VectorTransform` (hmg×aff) | `v: TVector; M: TAffineMatrix` | `TVector` | 齐次向量乘以仿射矩阵 |
| `VectorTransform` (aff×hmg) | `v: TAffineVector; M: TMatrix` | `TAffineVector` | 仿射向量乘以齐次矩阵 |
| `VectorTransform` (aff×aff) | `v: TAffineVector; M: TAffineMatrix` | `TAffineVector` | 仿射向量乘以仿射矩阵 |
| `TranslateMatrix` | `var M; v: TAffineVector` | - | 就地平移 |
| `TranslateMatrix` | `var M; v: TVector` | - | 就地平移（齐次） |
| `NormalizeMatrix` | `var M` | - | 归一化矩阵（移除平移，正交化） |
| `CreateLookAtMatrix` | `eye, center, normUp` | `TMatrix` | 观察矩阵 |
| `CreateMatrixFromFrustum` | `Left,Right,Bottom,Top,ZNear,ZFar` | `TMatrix` | 透视投影矩阵（视锥体） |
| `CreatePerspectiveMatrix` | `FOV, Aspect, ZNear, ZFar` | `TMatrix` | 透视投影矩阵 |
| `CreateOrthoMatrix` | `Left,Right,Bottom,Top,ZNear,ZFar` | `TMatrix` | 正交投影矩阵 |
| `CreatePickMatrix` | `x,y,deltax,deltay; viewport` | `TMatrix` | 选取矩阵 |
| `Project` | `objectVector; ViewProjMatrix; viewport; out WindowVector` | `Boolean` | 3D 点投影到窗口坐标 |
| `UnProject` | `WindowVector; ViewProjMatrix; viewport; out objectVector` | `Boolean` | 窗口坐标反投影到 3D |

### 4.4 矩阵分解与打包

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `MatrixDecompose` | `M; var Tran` | `Boolean` | 分解为变换参数序列 |
| `PackRotationMatrix` | `mat: TMatrix` | `TPackedRotationMatrix` | 压缩旋转矩阵为 6 字节 |
| `UnPackRotationMatrix` | `packedMatrix` | `TMatrix` | 解压缩旋转矩阵 |

---

## 5. 平面函数

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `PlaneMake` (3 pts aff) | `p1,p2,p3: TAffineVector` | `THmgPlane` | 三点确定平面 |
| `PlaneMake` (3 pts hmg) | `p1,p2,p3: TVector` | `THmgPlane` | 三点确定平面 |
| `PlaneMake` (pt+normal aff) | `Point, normal: TAffineVector` | `THmgPlane` | 点和法线确定平面 |
| `PlaneMake` (pt+normal hmg) | `Point, normal: TVector` | `THmgPlane` | 点和法线确定平面 |
| `NormalizePlane` | `var plane` | - | 归一化平面方程 |
| `PlaneEvaluatePoint` | `plane; Point: TAffineVector` | `TGeoFloat` | 点到平面有符号距离 |
| `PlaneEvaluatePoint` | `plane; Point: TVector` | `TGeoFloat` | 同上 |
| `CalcPlaneNormal` (aff) | `p1,p2,p3` | `TAffineVector` | 三点平面法线 |
| `CalcPlaneNormal` (aff proc) | `p1,p2,p3; var vr` | - | 法线结果存放 |
| `CalcPlaneNormal` (hmg) | `p1,p2,p3; var vr` | - | 法线结果存放 |
| `PointIsInHalfSpace` | 多种重载 | `Boolean` | 点是否在半空间 |
| `PointPlaneDistance` | 多种重载 | `TGeoFloat` | 点到平面距离 |
| `PointPlaneOrthoProjection` | `Point; plane; var inter; bothface` | `Boolean` | 点到平面的垂足 |
| `PointPlaneProjection` | `Point, direction, plane; var inter; bothface` | `Boolean` | 点沿方向投影到平面 |
| `SegmentPlaneIntersection` | `ptA,ptB; plane; var inter` | `Boolean` | 线段与平面交点 |
| `PointTriangleOrthoProjection` | `Point, ptA,ptB,ptC; var inter; bothface` | `Boolean` | 点在三角形上的垂足 |
| `PointTriangleProjection` | `Point, direction, ptA,ptB,ptC; var inter; bothface` | `Boolean` | 点沿方向投影到三角形 |
| `IsLineIntersectTriangle` | `Point, direction, ptA,ptB,ptC` | `Boolean` | 射线是否与三角形相交 |
| `PointQuadOrthoProjection` | `Point, ptA,ptB,ptC,ptD; var inter; bothface` | `Boolean` | 点在四边形上的垂足 |
| `PointQuadProjection` | `Point, direction, ptA,ptB,ptC,ptD; var inter; bothface` | `Boolean` | 点沿方向投影到四边形 |
| `IsLineIntersectQuad` | `Point, direction, ptA,ptB,ptC,ptD` | `Boolean` | 射线是否与四边形相交 |
| `PointDiskOrthoProjection` | `Point, center, up, radius; var inter; bothface` | `Boolean` | 点在圆盘上的垂足 |
| `PointDiskProjection` | `Point, direction, center, up, radius; var inter; bothface` | `Boolean` | 点沿方向投影到圆盘 |
| `PointLineClosestPoint` | `Point, linePoint, lineDirection` | `TAffineVector` | 点到直线最近点 |
| `PointLineDistance` | `Point, linePoint, lineDirection` | `TGeoFloat` | 点到直线距离 |
| `PointSegmentClosestPoint` (aff) | `Point, segmentStart, segmentStop` | `TAffineVector` | 点到线段最近点 |
| `PointSegmentClosestPoint` (hmg) | `Point, segmentStart, segmentStop` | `TVector` | 点到线段最近点 |
| `PointSegmentDistance` | `Point, segmentStart, segmentStop` | `TGeoFloat` | 点到线段距离 |
| `SegmentSegmentClosestPoint` | 两线段端点；var 两最近点 | - | 两线段最近点 |
| `SegmentSegmentDistance` | 两线段端点 | `TGeoFloat` | 两线段距离 |
| `LineLineDistance` | `linePt0,lineDir0,linePt1,lineDir1` | `TGeoFloat` | 两直线距离 |

---

## 6. 四元数函数

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `QuaternionMake` | `Imag: array; Real` | `TQuaternion` | 从虚部数组和实部创建四元数 |
| `QuaternionConjugate` | `q` | `TQuaternion` | 共轭四元数 |
| `QuaternionMagnitude` | `q` | `TGeoFloat` | 四元数模长 |
| `NormalizeQuaternion` | `var q` | - | 归一化四元数 |
| `QuaternionFromPoints` | `v1,v2: TAffineVector` | `TQuaternion` | 两点构造四元数 |
| `QuaternionToPoints` | `q; var ArcFrom, ArcTo` | - | 四元数转两点 |
| `QuaternionFromMatrix` | `mat: TMatrix` | `TQuaternion` | 从旋转矩阵提取四元数 |
| `QuaternionToMatrix` | `quat` | `TMatrix` | 四元数转旋转矩阵 |
| `QuaternionToAffineMatrix` | `quat` | `TAffineMatrix` | 四元数转仿射旋转矩阵 |
| `QuaternionFromAngleAxis` | `angle; axis` | `TQuaternion` | 角度和轴构造四元数 |
| `QuaternionFromRollPitchYaw` | `r,p,y` | `TQuaternion` | 欧拉角构造四元数 |
| `QuaternionFromEuler` | `x,y,z; eulerOrder` | `TQuaternion` | 任意顺序欧拉角构造四元数 |
| `QuaternionMultiply` | `qL,qR` | `TQuaternion` | 四元数乘法 |
| `QuaternionSlerp` | `QStart,QEnd; Spin; t` | `TQuaternion` | 球面线性插值（带旋转圈数） |
| `QuaternionSlerp` | `Source, dest; t` | `TQuaternion` | 球面线性插值 |

---

## 7. 插值与缓动函数

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `Lerp` | `Start, stop, t` | `TGeoFloat` | 线性插值 |
| `AngleLerp` | `Start, stop, t` | `TGeoFloat` | 角度线性插值（处理绕圈） |
| `MatrixLerp` | `m1,m2; Delta` | `TMatrix` | 矩阵逐元素线性插值 |
| `TexPointLerp` | `t1,t2; t` | `TTexPoint` | 纹理坐标线性插值 |
| `VectorLerp` (aff) | `v1,v2; t` | `TAffineVector` | 向量线性插值 |
| `VectorLerp` (hmg) | `v1,v2; t` | `TVector` | 齐次向量线性插值 |
| `VectorAngleLerp` | `v1,v2; t` | `TAffineVector` | 向量角度插值 |
| `VectorAngleCombine` | `v1,v2; f` | `TAffineVector` | v1 + f*v2 |
| `InterpolatePower` | `Start, stop, Delta, DistortionDegree` | `TGeoFloat` | 幂函数缓动 |
| `InterpolateLn` | `Start, stop, Delta, DistortionDegree` | `TGeoFloat` | 对数缓动 |
| `InterpolateExp` | `Start, stop, Delta, DistortionDegree` | `TGeoFloat` | 指数缓动 |
| `InterpolateSin` | `Start, stop, Delta` | `TGeoFloat` | 正弦缓动 |
| `InterpolateTan` | `Start, stop, Delta` | `TGeoFloat` | 正切缓动 |
| `InterpolateSinAlt` | `Start, stop, Delta` | `TGeoFloat` | 正弦替代（全局有效） |
| `InterpolateCombined` | `Start, stop, Delta, DistortionDegree, InterpolationType` | `TGeoFloat` | 组合插值 |
| `InterpolateCombinedFastPower` | `Original..., Target..., DistortionDegree` | `TGeoFloat` | 快速幂映射 |
| `InterpolateCombinedSafe` | 同上 + 类型 | `TGeoFloat` | 安全版本（处理除零） |
| `InterpolateCombinedFast` | 同上 | `TGeoFloat` | 快速版本 |

---

## 8. 三角函数与数学工具

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `DegToRad_` | `Degrees` | `Double / TGeoFloat` | 角度转弧度 |
| `RadToDeg_` | `Radians` | `Double / TGeoFloat` | 弧度转角度 |
| `NormalizeAngle` | `angle` | `TGeoFloat` | 归一化到 [-π, π] |
| `NormalizeDegAngle` | `angle` | `TGeoFloat` | 归一化到 [-180, 180] |
| `SinCos_` | `Theta` 及可选 `radius`，输出 | - | 同时计算 sin/cos |
| `PrepareSinCosCache` | `var s,c; startAngle, stopAngle` | - | 预计算 sin/cos 缓存 |
| `ArcCos_` | `x` | `Double / TGeoFloat` | 反余弦 |
| `ArcSin_` | `x` | `Double / TGeoFloat` | 反正弦 |
| `ArcTan2_` | `y,x` | `Double / TGeoFloat` | 反正切（四象限） |
| `FastArcTan2` | `y,x` | `TGeoFloat` | 快速反正切（精度 ~0.07 rad） |
| `Tan_` | `x` | `Double / TGeoFloat` | 正切 |
| `CoTan_` | `x` | `Double / TGeoFloat` | 余切 |
| `Sinh` / `Cosh` | `x` | `Double / TGeoFloat` | 双曲正弦/余弦 |
| `LnXP1_` | `x` | `Double` | ln(1+x) 精确计算 |
| `Log10_` | `x` | `Double` | 以 10 为底对数 |
| `Log2_` | `x` | `Double / TGeoFloat` | 以 2 为底对数 |
| `LogN_` | `Base, x` | `Double` | 任意底对数 |
| `IntPower_` | `Base, Exponent` | `Double` | 整数幂 |
| `Power_` (浮点指数) | `Base, Exponent` | `TGeoFloat` | 任意实数幂 |
| `Power_` (整数指数) | `Base, Exponent` | `TGeoFloat` | 整数幂 |
| `RSqrt` | `v` | `TGeoFloat` | 1/sqrt(v) |
| `RLength` | `x,y` | `TGeoFloat` | 1/sqrt(x²+y²) |
| `ISqrt` | `i` | `Integer` | 整数平方根近似 |
| `ILength` | `x,y` / `x,y,z` | `Integer` | 整数长度（sqrt 取整） |
| `RoundInt` | `v` | `TGeoFloat / Double` | 四舍五入为整数 |
| `Trunc` / `Round` / `Frac` | `x` | Int64 / Double | 标准取整/小数 |
| `Ceil` / `Ceil64` | `v` | Integer / Int64 | 向上取整 |
| `Floor` / `Floor64` | `v` | Integer / Int64 | 向下取整 |
| `Sign` | `x` | `Integer` | 符号函数 (-1,0,1) |
| `SignStrict` | `x` | `Integer` | 符号函数 (-1 或 1) |
| `IsInRange` | `x,a,b` | `Boolean` | 判断 x 是否在 [a,b] 内 |
| `IsInCube` | `p,d` | `Boolean` | 判断 p 是否在 [-d,d] 内 |
| `MinFloat` / `MaxFloat` | 多种重载 | 对应类型 | 求最小/最大值 |
| `MinInteger` / `MaxInteger` | 多种重载 | 对应类型 | 整数最小/最大值 |
| `ClampInteger` | `Value, Min_, Max_` | Integer / Cardinal | 整数截断 |
| `ClampValue` | `Value_, Min_, Max_` / `Value_, Min_` | `TGeoFloat` | 浮点截断 |
| `IsNan` | `Value_` | `Boolean` | 判断是否为 NaN |

---

## 9. 几何相交测试

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `RectanglesIntersect` | 两矩形中心/尺寸 | `Boolean` | 2D 矩形相交 |
| `RectangleContains` | 大矩形中心/尺寸，小矩形中心/尺寸 | `Boolean` | 大矩形包含小矩形 |
| `SphereVisibleRadius` | `Distance, radius` | `TGeoFloat` | 透视投影下球体可见半径 |
| `ExtractFrustumFromModelViewProjection` | `modelViewProj` | `TFrustum` | 从 MVP 提取视锥体裁剪面 |
| `IsVolumeClipped` | `objPos, objRadius, Frustum` | `Boolean` | 球体是否被裁剪 |
| `IsVolumeClipped` (box) | `Min_, Max_, Frustum` | `Boolean` | 包围盒是否被裁剪 |
| `RayCastPlaneIntersect` | `rayStart, rayVector, planePoint, planeNormal` | `Boolean` | 射线与平面交点 |
| `RayCastPlaneXZIntersect` | `rayStart, rayVector, planeY` | `Boolean` | 射线与水平面交点 |
| `RayCastTriangleIntersect` | `rayStart, rayVector, p1,p2,p3` | `Boolean` | 射线与三角形交点 |
| `RayCastMinDistToPoint` | `rayStart, rayVector, Point` | `TGeoFloat` | 射线到点最小距离 |
| `RayCastIntersectsSphere` | `rayStart, rayVector, sphereCenter, SphereRadius` | `Boolean` | 射线与球相交判定 |
| `RayCastSphereIntersect` | `rayStart, rayVector, sphereCenter, SphereRadius, var i1,i2` | `Integer` | 射线与球交点（0/1/2） |
| `RayCastBoxIntersect` | `rayStart, rayVector, aMinExtent, aMaxExtent` | `Boolean` | 射线与 AABB 交点 |
| `IntersectLinePlane` | `Point, direction, plane` | `Integer` | 直线与平面交点 |
| `IntersectTriangleBox` | `p1,p2,p3, aMinExtent, aMaxExtent` | `Boolean` | 三角形与 AABB 相交 |
| `IntersectSphereBox` | `SpherePos, SphereRadius, BoxMatrix, BoxScale` | `Boolean` | 球体与 OBB 相交 |

---

## 10. 坐标变换（Turn / Pitch / Roll）

| 函数 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `Turn` | `Matrix; angle` | `TMatrix` | 绕本地 Y 轴旋转 |
| `Turn` | `Matrix; MasterUp; angle` | `TMatrix` | 绕指定世界向上轴旋转 |
| `Pitch` | `Matrix; angle` | `TMatrix` | 绕本地 X 轴旋转 |
| `Pitch` | `Matrix; MasterRight; angle` | `TMatrix` | 绕指定世界右向量旋转 |
| `Roll` | `Matrix; angle` | `TMatrix` | 绕本地 Z 轴旋转 |
| `Roll` | `Matrix; MasterDirection; angle` | `TMatrix` | 绕指定世界方向旋转 |

---

## 11. 杂项工具

| 函数/过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `TriangleArea` | `p1,p2,p3` | `TGeoFloat` | 三角形面积 |
| `PolygonArea` | `p, nSides` | `TGeoFloat` | 多边形面积（必须共面） |
| `TriangleSignedArea` | `p1,p2,p3` | `TGeoFloat` | 2D 三角形有符号面积 |
| `PolygonSignedArea` | `p, nSides` | `TGeoFloat` | 2D 多边形有符号面积 |
| `SortArrayAscending` | `var a: array of Double` | - | 冒泡排序升序 |
| `DivMod` | `Dividend, Divisor; var Result, Remainder` | - | 整数除法及余数 |
| `PointInPolygon` | `var xp,yp; x,y` | `Boolean` | 点是否在多边形内 |
| `ConvertRotation` | `Angles: TAffineVector` | `TVector` | 欧拉角转绕轴旋转 |
| `RandomPointOnSphere` | `var p` | - | 单位球面随机点 |
| `MaxXYZComponent` / `MinXYZComponent` | 向量 | `TGeoFloat` | 取最大/最小分量 |
| `MaxAbsXYZComponent` / `MinAbsXYZComponent` | 向量 | `TGeoFloat` | 绝对值后最大/最小 |
| `MaxVector` / `MinVector` | 两个向量 | - | 分量取最大/最小（就地） |
| `ScaleAndRound` | `i; var s` | `Integer` | 缩放并四舍五入 |
| `MakeShadowMatrix` | `planePoint, planeNormal, lightPos` | `TMatrix` | 阴影投影矩阵 |
| `MakeReflectionMatrix` | `planePoint, planeNormal` | `TMatrix` | 反射矩阵 |
| `MakeParallelProjectionMatrix` | `plane, dir` | `TMatrix` | 平行投影矩阵 |
| `MoveObjectAround` | `MovingObjectPosition_, MovingObjectUp_, TargetPosition_; pitchDelta, turnDelta` | `TVector` | 绕目标点旋转物体 |
| `AngleBetweenVectors` | `a,b,ACenterPoint` | `TGeoFloat` | 两向量夹角 |
| `ShiftObjectFromCenter` | `OriginalPosition_, Center_, Distance_, FromCenterSpot_` | `TVector / TAffineVector` | 移近/远离中心 |
| `BarycentricCoordinates` | `v1,v2,v3,p; var u,v` | `Boolean` | 重心坐标，点在三角形内 |

---

> 本手册涵盖了 `Z.Geometry.Low` 接口部分所有导出成员。具体实现细节请参考源码。