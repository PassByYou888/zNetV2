# Z.Geometry.Low 完整 API 参考手册

> 本手册以表格形式列出 `Z.Geometry.Low` 单元的全部导出成员，按类别分组：**常量**、**类型定义**、**向量函数**、**矩阵函数**、**平面函数**、**四元数函数**、**插值与缓动函数**、**三角函数与数学工具**、**几何相交测试**、**坐标变换**、**杂项工具**。每个条目均附有说明。

---

## 目录

- [1. 常量](#1-常量)
- [2. 类型定义](#2-类型定义)
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
  - [4.2 矩阵运算（乘法、行列式、伴随、转置、逆）](#42-矩阵运算乘法行列式伴随转置逆)
  - [4.3 变换（向量变换、平移、缩放、归一化）](#43-变换向量变换平移缩放归一化)
  - [4.4 投影与视图矩阵](#44-投影与视图矩阵)
  - [4.5 矩阵分解与打包](#45-矩阵分解与打包)
- [5. 平面函数](#5-平面函数)
- [6. 四元数函数](#6-四元数函数)
- [7. 插值与缓动函数](#7-插值与缓动函数)
- [8. 三角函数与数学工具](#8-三角函数与数学工具)
- [9. 几何相交测试](#9-几何相交测试)
- [10. 坐标变换（Turn / Pitch / Roll）](#10-坐标变换turn--pitch--roll)
- [11. 杂项工具](#11-杂项工具)

---

## 1. 常量

| 常量名 | 类型 / 值 | 说明 |
| :--- | :--- | :--- |
| `XTexPoint` | `TTexPoint` | (s=1, t=0) 纹理坐标 (1,0) |
| `YTexPoint` | `TTexPoint` | (s=0, t=1) 纹理坐标 (0,1) |
| `XYTexPoint` | `TTexPoint` | (1,1) |
| `NullTexPoint` | `TTexPoint` | (0,0) |
| `MidTexPoint` | `TTexPoint` | (0.5,0.5) |
| `XVector` | `TAffineVector` | (1,0,0) 单位 X 轴 |
| `YVector` | `TAffineVector` | (0,1,0) 单位 Y 轴 |
| `ZVector` | `TAffineVector` | (0,0,1) 单位 Z 轴 |
| `XYVector` | `TAffineVector` | (1,1,0) |
| `XZVector` | `TAffineVector` | (1,0,1) |
| `YZVector` | `TAffineVector` | (0,1,1) |
| `XYZVector` | `TAffineVector` | (1,1,1) |
| `NullVector` | `TAffineVector` | (0,0,0) 零向量 |
| `MinusXVector` | `TAffineVector` | (-1,0,0) |
| `MinusYVector` | `TAffineVector` | (0,-1,0) |
| `MinusZVector` | `TAffineVector` | (0,0,-1) |
| `XHmgVector` | `THomogeneousVector` | (1,0,0,0) 齐次 X 方向 |
| `YHmgVector` | `THomogeneousVector` | (0,1,0,0) |
| `ZHmgVector` | `THomogeneousVector` | (0,0,1,0) |
| `WHmgVector` | `THomogeneousVector` | (0,0,0,1) |
| `XYHmgVector` | `THomogeneousVector` | (1,1,0,0) |
| `YZHmgVector` | `THomogeneousVector` | (0,1,1,0) |
| `XZHmgVector` | `THomogeneousVector` | (1,0,1,0) |
| `XYZHmgVector` | `THomogeneousVector` | (1,1,1,0) |
| `XYZWHmgVector` | `THomogeneousVector` | (1,1,1,1) |
| `NullHmgVector` | `THomogeneousVector` | (0,0,0,0) |
| `XHmgPoint` | `THomogeneousVector` | (1,0,0,1) 齐次点 |
| `YHmgPoint` | `THomogeneousVector` | (0,1,0,1) |
| `ZHmgPoint` | `THomogeneousVector` | (0,0,1,1) |
| `WHmgPoint` | `THomogeneousVector` | (0,0,0,1) |
| `NullHmgPoint` | `THomogeneousVector` | (0,0,0,1) |
| `IdentityMatrix` | `TAffineMatrix` | 3×3 单位矩阵 |
| `IdentityHmgMatrix` | `TMatrix` | 4×4 齐次单位矩阵 |
| `EmptyMatrix` | `TAffineMatrix` | 全零 3×3 矩阵 |
| `EmptyHmgMatrix` | `TMatrix` | 全零 4×4 矩阵 |
| `IdentityQuaternion` | `TQuaternion` | (0,0,0,1) 单位四元数 |
| `Epsilon` | `TGeoFloat` | 1E-40 极小值 |
| `EPSILON2` | `TGeoFloat` | 1E-30 常用容差 |
| `cPI` | `TGeoFloat` | π (3.141592654) |
| `cPIdiv180` | `TGeoFloat` | π/180 (0.017453292) |
| `c180divPI` | `TGeoFloat` | 180/π (57.29577951) |
| `c2PI` | `TGeoFloat` | 2π (6.283185307) |
| `cPIdiv2` | `TGeoFloat` | π/2 (1.570796326) |
| `cPIdiv4` | `TGeoFloat` | π/4 (0.785398163) |
| `c3PIdiv2` | `TGeoFloat` | 3π/2 (4.71238898) |
| `c3PIdiv4` | `TGeoFloat` | 3π/4 (2.35619449) |
| `cInv2PI` | `TGeoFloat` | 1/(2π) |
| `cInv360` | `TGeoFloat` | 1/360 |
| `c180` | `TGeoFloat` | 180 |
| `c360` | `TGeoFloat` | 360 |
| `cOneHalf` | `TGeoFloat` | 0.5 |
| `cLn10` | `TGeoFloat` | ln(10) (2.302585093) |
| `MinSingle` | `TGeoFloat` | 1.5E-45 |
| `MaxSingle` | `TGeoFloat` | 3.4E+38 |
| `MinDouble` | `Double` | 5.0E-324 |
| `MaxDouble` | `Double` | 1.7E+308 |
| `MinComp` | `Double` | -9.223372036854775807E+18 |
| `MaxComp` | `Double` | 9.223372036854775807E+18 |
| `CColinearBias` | `TGeoFloat` | 1E-8 共线判定容差 |
| `cZero` | `TGeoFloat` | 0 |
| `cOne` | `TGeoFloat` | 1 |
| `cOneDotFive` | `TGeoFloat` | 0.5 |
| `cEpsilon` | `TGeoFloat` | 1E-10 |

---

## 2. 类型定义

| 类型名 | 定义 | 说明 |
| :--- | :--- | :--- |
| `TVector2f` | `array[0..1] of TGeoFloat` | 2D 向量 |
| `TVector3f` | `array[0..2] of TGeoFloat` | 3D 向量 |
| `TVector4f` | `array[0..3] of TGeoFloat` | 4D 向量 |
| `TVector4i` | `array[0..3] of Integer` | 4D 整数向量 |
| `TMatrix2f` | `array[0..1] of TVector2f` | 2×2 矩阵 |
| `TMatrix3f` | `array[0..2] of TVector3f` | 3×3 矩阵（仿射） |
| `TMatrix4f` | `array[0..3] of TVector4f` | 4×4 矩阵（齐次） |
| `PFloat` | `^Single` | 单精度指针 |
| `PTexPoint` | `^TTexPoint` | 纹理坐标指针 |
| `TTexPoint` | `record s,t: TGeoFloat` | 纹理坐标 |
| `TFloatVector` | `array[0..MaxInt div SizeOf(TGeoFloat)-1] of TGeoFloat` | 连续浮点流 |
| `PFloatVector` | `^TFloatVector` | 浮点流指针 |
| `PFloatArray` | `PFloatVector` | 浮点数组指针 |
| `PSingleArray` | `PFloatArray` | 单精度数组指针 |
| `TSingleArray` | `array of TGeoFloat` | 单精度动态数组 |
| `TDoubleVector` | `array[0..MaxInt div SizeOf(Double)-1] of Double` | 双精度流 |
| `PDoubleVector` | `^TDoubleVector` | 双精度流指针 |
| `PDoubleArray` | `PDoubleVector` | 双精度数组指针 |
| `TDdoubleArray` | `array of Double` | 双精度动态数组 |
| `THomogeneousFltVector` | `TVector4f` | 齐次向量别名 |
| `TAffineFltVector` | `TVector3f` | 仿射向量别名 |
| `PVector2f` | `^TVector2f` | 2D 向量指针 |
| `TVector` | `THomogeneousFltVector` | 齐次向量（4D） |
| `PVector` | `^TVector` | 齐次向量指针 |
| `THomogeneousVector` | `THomogeneousFltVector` | 同 `TVector` |
| `PHomogeneousVector` | `^THomogeneousVector` | 同 `PVector` |
| `TAffineVector` | `TVector3f` | 仿射向量（3D） |
| `PAffineVector` | `^TAffineVector` | 仿射向量指针 |
| `TVertex` | `TAffineVector` | 顶点别名 |
| `PVertex` | `^TVertex` | 顶点指针 |
| `TAffineVectorArray` | `array[0..MaxInt div SizeOf(TAffineVector)-1] of TAffineVector` | 仿射向量数组 |
| `PAffineVectorArray` | `^TAffineVectorArray` | 仿射向量数组指针 |
| `TVectorArray` | `array[0..MaxInt div SizeOf(TVector)-1] of TVector` | 齐次向量数组 |
| `PVectorArray` | `^TVectorArray` | 齐次向量数组指针 |
| `TTexPointArray` | `array[0..MaxInt div SizeOf(TTexPoint)-1] of TTexPoint` | 纹理坐标数组 |
| `PTexPointArray` | `^TTexPointArray` | 纹理坐标数组指针 |
| `TMatrix` | `THomogeneousFltMatrix` (即 `TMatrix4f`) | 齐次矩阵 |
| `PMatrix` | `^TMatrix` | 齐次矩阵指针 |
| `TMatrixArray` | `array of TMatrix` | 齐次矩阵数组 |
| `PMatrixArray` | `^TMatrixArray` | 齐次矩阵数组指针 |
| `THomogeneousMatrix` | `THomogeneousFltMatrix` | 同 `TMatrix` |
| `PHomogeneousMatrix` | `^THomogeneousMatrix` | 同 `PMatrix` |
| `TAffineMatrix` | `TAffineFltMatrix` (即 `TMatrix3f`) | 仿射矩阵 |
| `PAffineMatrix` | `^TAffineMatrix` | 仿射矩阵指针 |
| `THmgPlane` | `TVector` | 平面方程 (A,B,C,D) |
| `TQuaternion` | `record ImagPart: TAffineVector; RealPart: TGeoFloat` | 四元数 |
| `PQuaternion` | `^TQuaternion` | 四元数指针 |
| `TQuaternionArray` | `array[0..MaxInt div SizeOf(TQuaternion)-1] of TQuaternion` | 四元数数组 |
| `PQuaternionArray` | `^TQuaternionArray` | 四元数数组指针 |
| `TRectangle` | `record Left,Top,width,height: Integer` | 整数矩形 |
| `TFrustum` | `record pLeft,pTop,pRight,pBottom,pNear,pFar: THmgPlane` | 视锥体裁剪平面组 |
| `TTransType` | 枚举 | 变换类型（平移、旋转、缩放、剪切、透视） |
| `TTransformations` | `array[TTransType] of TGeoFloat` | 变换参数数组 |
| `TPackedRotationMatrix` | `array[0..2] of SmallInt` | 压缩旋转矩阵（6 字节） |
| `TEulerOrder` | 枚举 | 欧拉角顺序 (eulXYZ, eulXZY, eulYXZ, eulYZX, eulZXY, eulZYX) |
| `TGLInterpolationType` | 枚举 | 插值类型 (itLinear, itPower, itSin, itSinAlt, itTan, itLn, itExp) |

---

## 3. 向量函数

### 3.1 构造与设置

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `TexPointMake` | `s, t: TGeoFloat` | `TTexPoint` | 创建纹理坐标 |
| `AffineVectorMake` | `x,y,z: TGeoFloat` | `TAffineVector` | 创建 3D 仿射向量 |
| `AffineVectorMake` | `v: TVector` | `TAffineVector` | 从齐次向量提取 3D 分量 |
| `SetAffineVector` | `out v: TAffineVector; x,y,z: TGeoFloat` | - | 设置仿射向量分量 |
| `SetVector` | `out v: TAffineVector; x,y,z: TGeoFloat` | - | 设置仿射向量分量 |
| `SetVector` | `out v: TAffineVector; vSrc: TVector` | - | 从齐次向量复制 3D 分量 |
| `SetVector` | `out v: TAffineVector; vSrc: TAffineVector` | - | 复制仿射向量 |
| `VectorMake` | `v: TAffineVector; w: TGeoFloat = 0` | `TVector` | 从 3D 向量创建齐次向量（w 可选） |
| `VectorMake` | `x,y,z: TGeoFloat; w: TGeoFloat = 0` | `TVector` | 从分量创建齐次向量 |
| `PointMake` | `x,y,z: TGeoFloat` | `TVector` | 创建齐次点 (w=1) |
| `PointMake` | `v: TAffineVector` | `TVector` | 从仿射向量创建齐次点 (w=1) |
| `PointMake` | `v: TVector` | `TVector` | 将齐次向量转为齐次点 (w=1) |
| `SetVector` | `out v: TVector; x,y,z: TGeoFloat; w: TGeoFloat = 0` | - | 设置齐次向量分量 |
| `SetVector` | `out v: TVector; av: TAffineVector; w: TGeoFloat = 0` | - | 从 3D 向量设置齐次向量 |
| `SetVector` | `out v: TVector; vSrc: TVector` | - | 复制齐次向量 |
| `MakePoint` | `out v: TVector; x,y,z: TGeoFloat` | - | 设置齐次点 (w=1) |
| `MakePoint` | `out v: TVector; av: TAffineVector` | - | 从仿射向量设置齐次点 |
| `MakePoint` | `out v: TVector; av: TVector` | - | 从齐次向量设置齐次点 (w=1) |
| `MakeVector` | `out v: TAffineVector; x,y,z: TGeoFloat` | - | 设置仿射向量（同 SetVector） |
| `MakeVector` | `out v: TVector; x,y,z: TGeoFloat` | - | 设置齐次方向 (w=0) |
| `MakeVector` | `out v: TVector; av: TAffineVector` | - | 从仿射向量设置齐次方向 |
| `MakeVector` | `out v: TVector; av: TVector` | - | 复制齐次向量并设 w=0 |
| `RstVector` | `var v: TAffineVector` | - | 将仿射向量置零 |
| `RstVector` | `var v: TVector` | - | 将齐次向量置零 |
| `Vector2fMake` | `x,y: TGeoFloat` | `TVector2f` | 创建 2D 向量 |
| `Vector2fMake` | `Vector: TVector3f` | `TVector2f` | 从 3D 向量取前两分量 |
| `Vector2fMake` | `Vector: TVector4f` | `TVector2f` | 从 4D 向量取前两分量 |
| `Vector3fMake` | `x: TGeoFloat; y=0; z=0` | `TVector3f` | 创建 3D 向量（带默认值） |
| `Vector3fMake` | `Vector: TVector2f; z=0` | `TVector3f` | 从 2D 向量创建 3D（z 默认 0） |
| `Vector3fMake` | `Vector: TVector4f` | `TVector3f` | 从 4D 向量取前三分量 |
| `Vector4fMake` | `x,y,z,w: TGeoFloat` | `TVector4f` | 创建 4D 向量 |
| `Vector4fMake` | `Vector: TVector3f; w=0` | `TVector4f` | 从 3D 向量创建 4D（w 默认 0） |
| `Vector4fMake` | `Vector: TVector2f; z=0; w=0` | `TVector4f` | 从 2D 向量创建 4D |

### 3.2 基本算术运算

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorAdd` (2f) | `v1,v2: TVector2f` | `TVector2f` | 2D 向量加法 |
| `VectorAdd` (affine) | `v1,v2: TAffineVector` | `TAffineVector` | 3D 向量加法 |
| `VectorAdd` (proc) | `v1,v2: TAffineVector; var vr` | - | 3D 向量加法，结果存放 |
| `VectorAdd` (proc, pointer) | `v1,v2: TAffineVector; vr: PAffineVector` | - | 同上，指针形式 |
| `VectorAdd` (hmg) | `v1,v2: TVector` | `TVector` | 齐次向量加法 |
| `VectorAdd` (hmg proc) | `v1,v2: TVector; var vr` | - | 齐次向量加法，结果存放 |
| `VectorAdd` (affine + scalar) | `v: TAffineVector; f: TGeoFloat` | `TAffineVector` | 向量每个分量加标量 |
| `VectorAdd` (hmg + scalar) | `v: TVector; f: TGeoFloat` | `TVector` | 齐次向量每个分量加标量 |
| `AddVector` (affine+affine) | `var v1: TAffineVector; v2: TAffineVector` | - | 就地加法 |
| `AddVector` (affine+hmg) | `var v1: TAffineVector; v2: TVector` | - | 就地加法（用 v2 的前 3 分量） |
| `AddVector` (hmg+hmg) | `var v1: TVector; v2: TVector` | - | 就地齐次加法 |
| `AddVector` (affine+scalar) | `var v: TAffineVector; f: TGeoFloat` | - | 就地标量加法 |
| `AddVector` (hmg+scalar) | `var v: TVector; f: TGeoFloat` | - | 就地齐次标量加法 |
| `AddPoint` | `var v1: TVector; const v2: TVector` | - | 齐次点加法（w 保持 1） |
| `PointAdd` | `var v1: TVector; v2: TVector` | `TVector` | 齐次点加法返回新点 (w=1) |
| `VectorSubtract` (2f) | `v1,v2: TVector2f` | `TVector2f` | 2D 向量减法 |
| `SubtractVector` (2f) | `var v1: TVector2f; v2: TVector2f` | - | 就地 2D 减法 |
| `VectorSubtract` (affine) | `v1,v2: TAffineVector` | `TAffineVector` | 3D 向量减法 |
| `VectorSubtract` (proc affine) | `v1,v2: TAffineVector; var Result` | - | 3D 减法，结果存放 |
| `VectorSubtract` (affine→hmg) | `v1,v2: TAffineVector; var Result: TVector` | - | 减法结果放入齐次向量 (w=0) |
| `VectorSubtract` (hmg→affine) | `v1: TVector; v2: TAffineVector; var Result: TVector` | - | 齐次 - 仿射，结果齐次 |
| `VectorSubtract` (hmg) | `v1,v2: TVector` | `TVector` | 齐次向量减法 |
| `VectorSubtract` (hmg proc) | `v1,v2: TVector; var Result` | - | 齐次减法结果存放 |
| `VectorSubtract` (hmg→affine) | `v1,v2: TVector; var Result: TAffineVector` | - | 齐次减法结果只保留 3D |
| `VectorSubtract` (affine-scalar) | `v1: TAffineVector; Delta: TGeoFloat` | `TAffineVector` | 每个分量减标量 |
| `VectorSubtract` (hmg-scalar) | `v1: TVector; Delta: TGeoFloat` | `TVector` | 齐次每个分量减标量 |
| `SubtractVector` (affine) | `var v1: TAffineVector; v2: TAffineVector` | - | 就地减法 |
| `SubtractVector` (hmg) | `var v1: TVector; v2: TVector` | - | 就地齐次减法 |
| `VectorCombine` (affine) | `v1,v2: TAffineVector; f1,f2: TGeoFloat` | `TAffineVector` | 线性组合 f1*v1 + f2*v2 |
| `VectorCombine` (hmg) | `v1,v2: TVector; f1,f2` | `TVector` | 线性组合（齐次） |
| `VectorCombine3` (affine) | `v1,v2,v3: TAffineVector; f1,f2,f3` | `TAffineVector` | 三个向量线性组合 |
| `VectorCombine3` (hmg) | `v1,v2,v3: TVector; f1,f2,f3` | `TVector` | 三个齐次向量线性组合 |
| `CombineVector` (affine) | `var vr: TAffineVector; v: TAffineVector; var f` | - | 就地 vr := vr + v*f |
| `CombineVector` (hmg) | `var vr: TVector; v: TVector; var f` | - | 就地齐次线性组合 |
| `TexPointCombine` | `t1,t2: TTexPoint; f1,f2` | `TTexPoint` | 纹理坐标线性组合 |
| `VectorScale` (2f) | `v: TVector2f; factor` | `TVector2f` | 2D 向量缩放 |
| `VectorScale` (affine) | `v: TAffineVector; factor` | `TAffineVector` | 3D 向量缩放 |
| `VectorScale` (hmg) | `v: TVector; factor` | `TVector` | 齐次向量缩放 |
| `VectorScale` (affine, vector factor) | `v, factor: TAffineVector` | `TAffineVector` | 分量乘法缩放 |
| `VectorScale` (hmg, vector factor) | `v, factor: TVector` | `TVector` | 齐次分量乘法缩放 |
| `ScaleVector` (2f) | `var v: TVector2f; factor` | - | 就地 2D 缩放 |
| `ScaleVector` (affine) | `var v: TAffineVector; factor` | - | 就地 3D 缩放 |
| `ScaleVector` (hmg) | `var v: TVector; factor` | - | 就地齐次缩放 |
| `ScaleVector` (affine vector) | `var v: TAffineVector; factor: TAffineVector` | - | 分量就地乘法 |
| `ScaleVector` (hmg vector) | `var v: TVector; factor: TVector` | - | 齐次分量就地乘法 |
| `VectorDivide` (hmg) | `v, divider: TVector` | `TVector` | 分量除法 |
| `VectorDivide` (affine) | `v, divider: TAffineVector` | `TAffineVector` | 分量除法 |
| `DivideVector` (hmg) | `var v: TVector; divider: TVector` | - | 就地分量除法 |
| `DivideVector` (affine) | `var v: TAffineVector; divider: TAffineVector` | - | 就地分量除法 |
| `NegateVector` (affine) | `var v: TAffineVector` | - | 就地取反 |
| `NegateVector` (hmg) | `var v: TVector` | - | 就地齐次取反 |
| `NegateVector` (array) | `var v: array of TGeoFloat` | - | 任意数组取反 |
| `VectorNegate` (affine) | `v: TAffineVector` | `TAffineVector` | 返回取反向量 |
| `VectorNegate` (hmg) | `v: TVector` | `TVector` | 返回取反齐次向量 |
| `AbsVector` (affine) | `var v: TAffineVector` | - | 每个分量取绝对值 |
| `AbsVector` (hmg) | `var v: TVector` | - | 齐次每个分量取绝对值 |
| `VectorAbs` (affine) | `v: TAffineVector` | `TAffineVector` | 返回绝对值向量 |
| `VectorAbs` (hmg) | `v: TVector` | `TVector` | 返回绝对值齐次向量 |

### 3.3 点积 / 叉积 / 投影

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorDotProduct` (2f) | `v1,v2: TVector2f` | `TGeoFloat` | 2D 点积 |
| `VectorDotProduct` (affine) | `v1,v2: TAffineVector` | `TGeoFloat` | 3D 点积 |
| `VectorDotProduct` (hmg) | `v1,v2: TVector` | `TGeoFloat` | 齐次点积（含 w） |
| `VectorDotProduct` (hmg×affine) | `v1: TVector; v2: TAffineVector` | `TGeoFloat` | 齐次前 3 分量与仿射点积 |
| `VectorCrossProduct` (affine) | `v1,v2: TAffineVector` | `TAffineVector` | 3D 叉积 |
| `VectorCrossProduct` (hmg) | `v1,v2: TVector` | `TVector` | 齐次叉积（w=0） |
| `VectorCrossProduct` (hmg proc) | `v1,v2: TVector; var vr` | - | 齐次叉积结果存放 |
| `VectorCrossProduct` (aff→hmg) | `v1,v2: TAffineVector; var vr: TVector` | - | 叉积结果放入齐次（w=0） |
| `VectorCrossProduct` (hmg→aff) | `v1,v2: TVector; var vr: TAffineVector` | - | 叉积结果只保留 3D |
| `VectorCrossProduct` (aff proc) | `v1,v2: TAffineVector; var vr: TAffineVector` | - | 叉积结果存放 |
| `PointProject` (affine) | `p, origin, direction: TAffineVector` | `TGeoFloat` | 投影距离 (p-origin)·direction |
| `PointProject` (hmg) | `p, origin, direction: TVector` | `TGeoFloat` | 同上，齐次版本 |

### 3.4 长度 / 范数 / 归一化

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorLength` (x,y) | `x,y: TGeoFloat` | `TGeoFloat` | sqrt(x²+y²) |
| `VectorLength` (x,y,z) | `x,y,z: TGeoFloat` | `TGeoFloat` | sqrt(x²+y²+z²) |
| `VectorLength` (2f) | `v: TVector2f` | `TGeoFloat` | 2D 向量长度 |
| `VectorLength` (affine) | `v: TAffineVector` | `TGeoFloat` | 3D 向量长度 |
| `VectorLength` (hmg) | `v: TVector` | `TGeoFloat` | 3D 长度（忽略 w） |
| `VectorLength` (array) | `v: array of TGeoFloat` | `TGeoFloat` | 任意维长度 |
| `VectorNorm` (x,y) | `x,y: TGeoFloat` | `TGeoFloat` | x²+y² |
| `VectorNorm` (affine) | `v: TAffineVector` | `TGeoFloat` | 范数（平方长度） |
| `VectorNorm` (hmg) | `v: TVector` | `TGeoFloat` | 忽略 w 的范数 |
| `VectorNorm` (array) | `var v: array of TGeoFloat` | `TGeoFloat` | 任意维范数 |
| `NormalizeVector` (2f) | `var v: TVector2f` | - | 就地归一化 |
| `NormalizeVector` (affine) | `var v: TAffineVector` | - | 就地归一化 |
| `NormalizeVector` (hmg) | `var v: TVector` | - | 就地归一化（w 置 0） |
| `VectorNormalize` (2f) | `v: TVector2f` | `TVector2f` | 返回归一化向量 |
| `VectorNormalize` (affine) | `v: TAffineVector` | `TAffineVector` | 返回归一化向量 |
| `VectorNormalize` (hmg) | `v: TVector` | `TVector` | 返回归一化齐次向量（w=0） |

### 3.5 比较与判定

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorEquals` (2f) | `v1,v2: TVector2f` | `Boolean` | 2D 向量相等 |
| `VectorEquals` (affine) | `v1,v2: TAffineVector` | `Boolean` | 3D 向量相等 |
| `VectorEquals` (hmg) | `v1,v2: TVector` | `Boolean` | 齐次向量相等 |
| `AffineVectorEquals` | `v1,v2: TVector` | `Boolean` | 仅比较前 3 分量 |
| `VectorIsNull` (affine) | `v: TAffineVector` | `Boolean` | 是否零向量 |
| `VectorIsNull` (hmg) | `v: TVector` | `Boolean` | 是否零向量（忽略 w） |
| `TexpointEquals` | `p1,p2: TTexPoint` | `Boolean` | 纹理坐标相等 |
| `IsColinear` (2f) | `v1,v2: TVector2f` | `Boolean` | 是否共线 |
| `IsColinear` (affine) | `v1,v2: TAffineVector` | `Boolean` | 是否共线 |
| `IsColinear` (hmg) | `v1,v2: TVector` | `Boolean` | 是否共线（忽略 w） |
| `VectorMoreThen` (3f/4f) | 向量比较 | `Boolean` | 所有分量大于 |
| `VectorMoreEqualThen` | 向量比较 | `Boolean` | 所有分量大于等于 |
| `VectorLessThen` | 向量比较 | `Boolean` | 所有分量小于 |
| `VectorLessEqualThen` | 向量比较 | `Boolean` | 所有分量小于等于 |
| （均提供 ComparedNumber 版本） | 向量与标量比较 | `Boolean` | 同上 |

### 3.6 缩放 / 取反 / 取绝对值（已包含在 3.2 和 3.5）

（无额外函数）

### 3.7 旋转

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `RotateVector` | `var Vector: TVector; axis: TAffineVector; angle` | - | 绕轴旋转齐次向量（角度弧度） |
| `RotateVector` | `var Vector: TVector; axis: TVector; angle` | - | 同上，轴为齐次 |
| `RotateVectorAroundY` | `var v: TAffineVector; alpha` | - | 绕 Y 轴旋转（就地） |
| `VectorRotateAroundX` | `v: TAffineVector; alpha` | `TAffineVector` | 绕 X 轴旋转返回 |
| `VectorRotateAroundY` | `v: TAffineVector; alpha` | `TAffineVector` | 绕 Y 轴旋转返回 |
| `VectorRotateAroundY` (proc) | `v: TAffineVector; alpha; var vr` | - | 绕 Y 轴旋转结果存放 |
| `VectorRotateAroundZ` | `v: TAffineVector; alpha` | `TAffineVector` | 绕 Z 轴旋转返回 |

### 3.8 数组批量操作

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorArrayAdd` | `Src, Delta, nb, dest` | - | 将 Delta 加到每个向量 |
| `VectorArrayLerp` (hmg) | `src1, src2, t, n, dest` | - | 批量线性插值（齐次） |
| `VectorArrayLerp` (affine) | `src1, src2, t, n, dest` | - | 批量线性插值（仿射） |
| `VectorArrayLerp` (texpoint) | `src1, src2, t, n, dest` | - | 批量纹理坐标插值 |
| `NormalizeVectorArray` | `List: PAffineVectorArray; n` | - | 批量归一化 |
| `TexPointArrayAdd` | `Src, Delta, nb, dest` | - | 批量纹理坐标加法 |
| `TexPointArrayScaleAndAdd` | `Src, Delta, nb, Scale, dest` | - | 缩放并加 Delta |
| `ScaleFloatArray` (raw) | `values, nb, factor` | - | 批量浮点数缩放 |
| `ScaleFloatArray` (array) | `var values: TSingleArray; factor` | - | 批量缩放 |
| `OffsetFloatArray` (raw) | `values, nb, Delta` | - | 批量加 Delta |
| `OffsetFloatArray` (array) | `var values: array of TGeoFloat; Delta` | - | 批量加 Delta |
| `OffsetFloatArray` (dest+delta) | `valuesDest, valuesDelta, nb` | - | 目标 = 目标 + 增量 |

---

## 4. 矩阵函数

### 4.1 构造与设置

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `SetMatrix` | `var dest: TAffineMatrix; const Src: TMatrix` | - | 从齐次矩阵复制 3×3 部分 |
| `SetMatrix` | `var dest: TMatrix; const Src: TAffineMatrix` | - | 从仿射矩阵扩展为齐次矩阵（w 行/列置 0/1） |
| `SetMatrixRow` | `var dest: TMatrix; rowNb: Integer; const aRow: TVector` | - | 设置矩阵的某一行 |
| `CreateScaleMatrix` | `v: TAffineVector` | `TMatrix` | 创建缩放矩阵（仿射） |
| `CreateScaleMatrix` | `v: TVector` | `TMatrix` | 创建缩放矩阵（齐次） |
| `CreateTranslationMatrix` | `v: TAffineVector` | `TMatrix` | 创建平移矩阵 |
| `CreateTranslationMatrix` | `v: TVector` | `TMatrix` | 创建平移矩阵 |
| `CreateScaleAndTranslationMatrix` | `Scale, Offset: TVector` | `TMatrix` | 创建缩放+平移矩阵（先缩放后平移） |
| `CreateRotationMatrixX` | `sine, cosine: TGeoFloat` | `TMatrix` | 用给定的 sin/cos 创建 X 旋转矩阵 |
| `CreateRotationMatrixX` | `angle: TGeoFloat` | `TMatrix` | 创建绕 X 轴旋转矩阵（角度弧度） |
| `CreateRotationMatrixY` | `sine, cosine` / `angle` | `TMatrix` | 绕 Y 轴旋转矩阵 |
| `CreateRotationMatrixZ` | `sine, cosine` / `angle` | `TMatrix` | 绕 Z 轴旋转矩阵 |
| `CreateRotationMatrix` | `anAxis: TAffineVector; angle` | `TMatrix` | 绕任意轴旋转矩阵 |
| `CreateRotationMatrix` | `anAxis: TVector; angle` | `TMatrix` | 绕任意轴旋转矩阵（齐次轴） |
| `CreateAffineRotationMatrix` | `anAxis: TAffineVector; angle` | `TAffineMatrix` | 创建仿射旋转矩阵 |

### 4.2 矩阵运算（乘法、行列式、伴随、转置、逆）

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `MatrixMultiply` (affine) | `m1,m2: TAffineMatrix` | `TAffineMatrix` | 3×3 矩阵乘法 |
| `MatrixMultiply` (hmg) | `m1,m2: TMatrix` | `TMatrix` | 4×4 矩阵乘法 |
| `MatrixMultiply` (proc) | `m1,m2: TMatrix; var MResult` | - | 4×4 乘法，结果存放 |
| `MatrixDeterminant` (affine) | `M: TAffineMatrix` | `TGeoFloat` | 3×3 行列式 |
| `MatrixDeterminant` (hmg) | `M: TMatrix` | `TGeoFloat` | 4×4 行列式 |
| `AdjointMatrix` (hmg) | `var M: TMatrix` | - | 计算伴随矩阵（用于逆） |
| `AdjointMatrix` (affine) | `var M: TAffineMatrix` | - | 3×3 伴随矩阵 |
| `ScaleMatrix` (affine) | `var M: TAffineMatrix; factor` | - | 矩阵所有元素乘以因子 |
| `ScaleMatrix` (hmg) | `var M: TMatrix; factor` | - | 齐次矩阵所有元素乘以因子 |
| `TransposeMatrix` (affine) | `var M: TAffineMatrix` | - | 转置 3×3 |
| `TransposeMatrix` (hmg) | `var M: TMatrix` | - | 转置 4×4 |
| `InvertMatrix` (hmg) | `var M: TMatrix` | - | 就地求逆（若奇异则置单位阵） |
| `MatrixInvert` (hmg) | `M: TMatrix` | `TMatrix` | 返回逆矩阵 |
| `InvertMatrix` (affine) | `var M: TAffineMatrix` | - | 就地 3×3 求逆 |
| `MatrixInvert` (affine) | `M: TAffineMatrix` | `TAffineMatrix` | 返回 3×3 逆 |
| `AnglePreservingMatrixInvert` | `mat: TMatrix` | `TMatrix` | 角度保持矩阵的快速逆（正交+各向同性缩放） |
| `MatrixDecompose` | `M: TMatrix; var Tran: TTransformations` | `Boolean` | 分解矩阵为变换参数（平移、旋转、缩放、剪切、透视） |

### 4.3 变换（向量变换、平移、缩放、归一化）

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `VectorTransform` (hmg×hmg) | `v: TVector; M: TMatrix` | `TVector` | 齐次向量乘以矩阵 |
| `VectorTransform` (hmg×aff) | `v: TVector; M: TAffineMatrix` | `TVector` | 齐次向量乘以仿射矩阵（w 不变） |
| `VectorTransform` (aff×hmg) | `v: TAffineVector; M: TMatrix` | `TAffineVector` | 仿射向量乘以齐次矩阵（w=1 投影） |
| `VectorTransform` (aff×aff) | `v: TAffineVector; M: TAffineMatrix` | `TAffineVector` | 仿射向量乘以仿射矩阵 |
| `TranslateMatrix` | `var M: TMatrix; v: TAffineVector` | - | 就地平移 |
| `TranslateMatrix` | `var M: TMatrix; v: TVector` | - | 就地平移（齐次向量） |
| `NormalizeMatrix` | `var M: TMatrix` | - | 归一化矩阵（移除平移，正交化旋转部分） |

### 4.4 投影与视图矩阵

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `CreateLookAtMatrix` | `eye, center, normUp: TVector` | `TMatrix` | 观察矩阵（LookAt） |
| `CreateMatrixFromFrustum` | `Left,Right,Bottom,Top,ZNear,ZFar` | `TMatrix` | 透视投影矩阵（视锥体） |
| `CreatePerspectiveMatrix` | `FOV, Aspect, ZNear, ZFar` | `TMatrix` | 透视投影矩阵（视角、宽高比） |
| `CreateOrthoMatrix` | `Left,Right,Bottom,Top,ZNear,ZFar` | `TMatrix` | 正交投影矩阵 |
| `CreatePickMatrix` | `x,y,deltax,deltay: TGeoFloat; viewport: TVector4i` | `TMatrix` | 选取矩阵（用于拾取） |
| `Project` | `objectVector: TVector; ViewProjMatrix: TMatrix; viewport: TVector4i; out WindowVector: TVector` | `Boolean` | 将 3D 点投影到窗口坐标 |
| `UnProject` | `WindowVector: TVector; ViewProjMatrix: TMatrix; viewport: TVector4i; out objectVector: TVector` | `Boolean` | 窗口坐标反投影到 3D |

### 4.5 矩阵分解与打包

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `PackRotationMatrix` | `mat: TMatrix` | `TPackedRotationMatrix` | 压缩旋转矩阵为 3 个 16 位整数（基于四元数） |
| `UnPackRotationMatrix` | `packedMatrix: TPackedRotationMatrix` | `TMatrix` | 解压缩为旋转矩阵 |

---

## 5. 平面函数

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `PlaneMake` (3 points, affine) | `p1,p2,p3: TAffineVector` | `THmgPlane` | 由三点确定平面 |
| `PlaneMake` (3 points, hmg) | `p1,p2,p3: TVector` | `THmgPlane` | 由三点确定平面 |
| `PlaneMake` (point+normal, affine) | `Point, normal: TAffineVector` | `THmgPlane` | 由点和法线确定平面 |
| `PlaneMake` (point+normal, hmg) | `Point, normal: TVector` | `THmgPlane` | 由点和法线确定平面 |
| `NormalizePlane` | `var plane: THmgPlane` | - | 归一化平面方程（法线单位化） |
| `PlaneEvaluatePoint` | `plane: THmgPlane; Point: TAffineVector` | `TGeoFloat` | 计算点到平面的有符号距离 |
| `PlaneEvaluatePoint` | `plane: THmgPlane; Point: TVector` | `TGeoFloat` | 同上 |
| `CalcPlaneNormal` (affine) | `p1,p2,p3: TAffineVector` | `TAffineVector` | 计算三点平面的法线 |
| `CalcPlaneNormal` (proc) | `p1,p2,p3: TAffineVector; var vr` | - | 法线结果存放 |
| `CalcPlaneNormal` (hmg) | `p1,p2,p3: TVector; var vr: TAffineVector` | - | 法线结果存放 |
| `PointIsInHalfSpace` | `Point, planePoint, planeNormal: TVector` / `TAffineVector` | `Boolean` | 点是否在半空间（法线方向） |
| `PointIsInHalfSpace` | `Point: TAffineVector; plane: THmgPlane` | `Boolean` | 点是否在半空间 |
| `PointPlaneDistance` (多种重载) | 点、平面参数 | `TGeoFloat` | 点到平面距离（有符号） |
| `PointPlaneOrthoProjection` | `Point: TAffineVector; plane: THmgPlane; var inter; bothface` | `Boolean` | 点投影到平面的垂足 |
| `PointPlaneProjection` | `Point, direction, plane; var inter; bothface` | `Boolean` | 点沿方向投影到平面 |
| `SegmentPlaneIntersection` | `ptA,ptB: TAffineVector; plane: THmgPlane; var inter` | `Boolean` | 线段与平面交点 |
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
| `PointSegmentClosestPoint` (affine) | `Point, segmentStart, segmentStop` | `TAffineVector` | 点到线段最近点 |
| `PointSegmentClosestPoint` (hmg) | `Point, segmentStart, segmentStop` | `TVector` | 点到线段最近点（齐次） |
| `PointSegmentDistance` | `Point, segmentStart, segmentStop` | `TGeoFloat` | 点到线段距离 |
| `SegmentSegmentClosestPoint` | `S0Start,S0Stop,S1Start,S1Stop; var Segment0Closest, Segment1Closest` | - | 两线段最近点 |
| `SegmentSegmentDistance` | `S0Start,S0Stop,S1Start,S1Stop` | `TGeoFloat` | 两线段距离 |
| `LineLineDistance` | `linePt0,lineDir0,linePt1,lineDir1` | `TGeoFloat` | 两直线距离 |

---

## 6. 四元数函数

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `QuaternionMake` | `Imag: array of TGeoFloat; Real: TGeoFloat` | `TQuaternion` | 创建四元数（虚部数组长度至少 3） |
| `QuaternionConjugate` | `q: TQuaternion` | `TQuaternion` | 共轭四元数 |
| `QuaternionMagnitude` | `q: TQuaternion` | `TGeoFloat` | 四元数模长 |
| `NormalizeQuaternion` | `var q: TQuaternion` | - | 归一化四元数 |
| `QuaternionFromPoints` | `v1,v2: TAffineVector` | `TQuaternion` | 由两点（单位球面上）构造四元数（旋转） |
| `QuaternionToPoints` | `q: TQuaternion; var ArcFrom, ArcTo` | - | 从四元数提取两点（用于弧插值） |
| `QuaternionFromMatrix` | `mat: TMatrix` | `TQuaternion` | 从旋转矩阵提取四元数 |
| `QuaternionToMatrix` | `quat: TQuaternion` | `TMatrix` | 四元数转旋转矩阵（齐次） |
| `QuaternionToAffineMatrix` | `quat: TQuaternion` | `TAffineMatrix` | 四元数转仿射旋转矩阵 |
| `QuaternionFromAngleAxis` | `angle: TGeoFloat; axis: TAffineVector` | `TQuaternion` | 由角度（度）和轴构造四元数 |
| `QuaternionFromRollPitchYaw` | `r,p,y: TGeoFloat` | `TQuaternion` | 由欧拉角（滚转、俯仰、偏航，度）构造四元数 |
| `QuaternionFromEuler` | `x,y,z: TGeoFloat; eulerOrder: TEulerOrder` | `TQuaternion` | 由欧拉角（度）和顺序构造四元数 |
| `QuaternionMultiply` | `qL,qR: TQuaternion` | `TQuaternion` | 四元数乘法（qL * qR） |
| `QuaternionSlerp` | `QStart,QEnd: TQuaternion; Spin: Integer; t: TGeoFloat` | `TQuaternion` | 球面线性插值（带旋转圈数） |
| `QuaternionSlerp` | `Source, dest: TQuaternion; t: TGeoFloat` | `TQuaternion` | 球面线性插值（标准） |

---

## 7. 插值与缓动函数

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `Lerp` | `Start, stop, t: TGeoFloat` | `TGeoFloat` | 线性插值 |
| `AngleLerp` | `Start, stop, t: TGeoFloat` | `TGeoFloat` | 角度线性插值（处理绕圈） |
| `MatrixLerp` | `m1,m2: TMatrix; Delta: TGeoFloat` | `TMatrix` | 矩阵逐元素线性插值 |
| `TexPointLerp` | `t1,t2: TTexPoint; t: TGeoFloat` | `TTexPoint` | 纹理坐标线性插值 |
| `VectorLerp` (affine) | `v1,v2: TAffineVector; t` | `TAffineVector` | 向量线性插值 |
| `VectorLerp` (hmg) | `v1,v2: TVector; t` | `TVector` | 齐次向量线性插值 |
| `VectorAngleLerp` | `v1,v2: TAffineVector; t` | `TAffineVector` | 向量角度插值（四元数 SLERP 再分解） |
| `VectorAngleCombine` | `v1,v2: TAffineVector; f` | `TAffineVector` | v1 + f*v2 |
| `InterpolatePower` | `Start, stop, Delta, DistortionDegree` | `TGeoFloat` | 幂函数缓动 |
| `InterpolateLn` | `Start, stop, Delta, DistortionDegree` | `TGeoFloat` | 对数缓动 |
| `InterpolateExp` | `Start, stop, Delta, DistortionDegree` | `TGeoFloat` | 指数缓动 |
| `InterpolateSin` | `Start, stop, Delta` | `TGeoFloat` | 正弦缓动（0..1） |
| `InterpolateTan` | `Start, stop, Delta` | `TGeoFloat` | 正切缓动（0..1） |
| `InterpolateSinAlt` | `Start, stop, Delta` | `TGeoFloat` | 正弦替代（全部有效） |
| `InterpolateCombined` | `Start, stop, Delta, DistortionDegree, InterpolationType` | `TGeoFloat` | 组合插值（根据类型） |
| `InterpolateCombinedFastPower` | `OriginalStart,OriginalStop,OriginalCurrent, TargetStart,TargetStop, DistortionDegree` | `TGeoFloat` | 快速幂映射 |
| `InterpolateCombinedSafe` | 同 fast 但加类型 | `TGeoFloat` | 安全版本（处理除零） |
| `InterpolateCombinedFast` | 同 safe | `TGeoFloat` | 快速版本（不处理除零） |

---

## 8. 三角函数与数学工具

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `DegToRad_` | `Degrees: Double / TGeoFloat` | 对应类型 | 角度转弧度 |
| `RadToDeg_` | `Radians: Double / TGeoFloat` | 对应类型 | 弧度转角度 |
| `NormalizeAngle` | `angle: TGeoFloat` | `TGeoFloat` | 归一化到 [-π, π] |
| `NormalizeDegAngle` | `angle: TGeoFloat` | `TGeoFloat` | 归一化到 [-180, 180] |
| `SinCos_` (多种重载) | `Theta` 及可选 `radius`，输出 `Sin,Cos` | - | 同时计算 sin/cos |
| `PrepareSinCosCache` | `var s,c: array of TGeoFloat; startAngle, stopAngle` | - | 预计算 sin/cos 缓存 |
| `ArcCos_` | `x: Double / TGeoFloat` | 对应类型 | 反余弦 |
| `ArcSin_` | `x: Double / TGeoFloat` | 对应类型 | 反正弦 |
| `ArcTan2_` | `y,x: Double / TGeoFloat` | 对应类型 | 反正切（四象限） |
| `FastArcTan2` | `y,x: TGeoFloat` | `TGeoFloat` | 快速反正切（精度约 0.07 rad） |
| `Tan_` | `x: Double / TGeoFloat` | 对应类型 | 正切 |
| `CoTan_` | `x: Double / TGeoFloat` | 对应类型 | 余切 |
| `Sinh` / `Cosh` | `x: Double / TGeoFloat` | 对应类型 | 双曲正弦/余弦 |
| `LnXP1_` | `x: Double` | `Double` | ln(1+x) 精确计算 |
| `Log10_` | `x: Double` | `Double` | 以 10 为底对数 |
| `Log2_` | `x: Double / TGeoFloat` | 对应类型 | 以 2 为底对数 |
| `LogN_` | `Base, x: Double` | `Double` | 以任意底对数 |
| `IntPower_` | `Base: Double; Exponent: Integer` | `Double` | 整数幂 |
| `Power_` (浮点指数) | `Base, Exponent: TGeoFloat` | `TGeoFloat` | 任意实数幂 |
| `Power_` (整数指数) | `Base: TGeoFloat; Exponent: Integer / Int64` | `TGeoFloat` | 整数幂 |
| `RSqrt` | `v: TGeoFloat` | `TGeoFloat` | 1/sqrt(v) |
| `RLength` | `x,y: TGeoFloat` | `TGeoFloat` | 1/sqrt(x²+y²) |
| `ISqrt` | `i: Integer` | `Integer` | 整数平方根（近似） |
| `ILength` | `x,y: Integer` / `x,y,z: Integer` | `Integer` | 整数长度（sqrt 取整） |
| `RoundInt` | `v: TGeoFloat / Double` | 对应类型 | 四舍五入为整数（浮点返回） |
| `Trunc` / `Round` / `Frac` | `x: Double` | Int64 / Double | 标准取整/小数 |
| `Ceil` / `Ceil64` | `v: TGeoFloat / Double` | Integer / Int64 | 向上取整 |
| `Floor` / `Floor64` | `v: TGeoFloat / Double` | Integer / Int64 | 向下取整 |
| `Sign` | `x: TGeoFloat` | `Integer` | 符号函数（-1,0,1） |
| `SignStrict` | `x: TGeoFloat` | `Integer` | 符号函数（-1 或 1，不含 0） |
| `IsInRange` | `x,a,b: TGeoFloat / Double` | `Boolean` | 判断 x 是否在 [a,b] 内 |
| `IsInCube` | `p,d: TAffineVector / TVector` | `Boolean` | 判断 p 是否在 [-d,d] 立方体内 |
| `MinFloat` / `MaxFloat` | 多种重载（数组/多参数） | 对应类型 | 求最小/最大值 |
| `MinInteger` / `MaxInteger` | 多种重载 | 对应类型 | 整数最小/最大值 |
| `ClampInteger` | `Value, Min_, Max_` | Integer / Cardinal | 整数截断 |
| `ClampValue` | `Value_, Min_, Max_` / `Value_, Min_` | `TGeoFloat` | 浮点截断（无边/有边） |

---

## 9. 几何相交测试

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `RectanglesIntersect` | `CenterOfRect_1, CenterOfRect_2, SizeOfRect_1, SizeOfRect_2: TVector2f` | `Boolean` | 2D 矩形相交判定 |
| `RectangleContains` | 大矩形中心/尺寸，小矩形中心/尺寸，Eps | `Boolean` | 大矩形是否包含小矩形 |
| `SphereVisibleRadius` | `Distance, radius` | `TGeoFloat` | 透视投影下球体可见半径 |
| `ExtractFrustumFromModelViewProjection` | `modelViewProj: TMatrix` | `TFrustum` | 从 MVP 矩阵提取视锥体裁剪面 |
| `IsVolumeClipped` | `objPos: TAffineVector/TVector; objRadius; Frustum` | `Boolean` | 球体是否被裁剪 |
| `IsVolumeClipped` | `Min_, Max_: TAffineVector; Frustum` | `Boolean` | 包围盒是否被裁剪 |
| `RayCastPlaneIntersect` | `rayStart, rayVector, planePoint, planeNormal; intersectPoint` | `Boolean` | 射线与平面交点 |
| `RayCastPlaneXZIntersect` | `rayStart, rayVector; planeY; intersectPoint` | `Boolean` | 射线与水平面（y=planeY）交点 |
| `RayCastTriangleIntersect` | `rayStart, rayVector; p1,p2,p3; intersectPoint, intersectNormal` | `Boolean` | 射线与三角形交点 |
| `RayCastMinDistToPoint` | `rayStart, rayVector; Point` | `TGeoFloat` | 射线到点的最小距离 |
| `RayCastIntersectsSphere` | `rayStart, rayVector; sphereCenter; SphereRadius` | `Boolean` | 射线是否与球相交 |
| `RayCastSphereIntersect` | `rayStart, rayVector; sphereCenter; SphereRadius; var i1,i2` | `Integer` | 射线与球交点（0/1/2） |
| `RayCastBoxIntersect` | `rayStart, rayVector; aMinExtent,aMaxExtent; intersectPoint` | `Boolean` | 射线与 AABB 交点 |
| `IntersectLinePlane` | `Point, direction; plane; intersectPoint` | `Integer` | 直线与平面交点（0/1/-1） |
| `IntersectTriangleBox` | `p1,p2,p3; aMinExtent,aMaxExtent` | `Boolean` | 三角形与 AABB 相交 |
| `IntersectSphereBox` | `SpherePos, SphereRadius; BoxMatrix; BoxScale; intersectPoint, normal, Depth` | `Boolean` | 球体与 OBB 相交 |

---

## 10. 坐标变换（Turn / Pitch / Roll）

| 函数 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `Turn` | `Matrix: TMatrix; angle` | `TMatrix` | 绕矩阵的 Y 轴（本地向上）旋转 |
| `Turn` | `Matrix: TMatrix; MasterUp: TAffineVector; angle` | `TMatrix` | 绕指定世界向上轴旋转 |
| `Pitch` | `Matrix: TMatrix; angle` | `TMatrix` | 绕矩阵的 X 轴（本地右向量）旋转 |
| `Pitch` | `Matrix: TMatrix; MasterRight: TAffineVector; angle` | `TMatrix` | 绕指定世界右向量旋转 |
| `Roll` | `Matrix: TMatrix; angle` | `TMatrix` | 绕矩阵的 Z 轴（本地方向）旋转 |
| `Roll` | `Matrix: TMatrix; MasterDirection: TAffineVector; angle` | `TMatrix` | 绕指定世界方向旋转 |

---

## 11. 杂项工具

| 函数 / 过程 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `TriangleArea` | `p1,p2,p3: TAffineVector` | `TGeoFloat` | 三角形面积 |
| `PolygonArea` | `p: PAffineVectorArray; nSides` | `TGeoFloat` | 多边形面积（必须共面） |
| `TriangleSignedArea` | `p1,p2,p3: TAffineVector` | `TGeoFloat` | 2D 三角形有符号面积 |
| `PolygonSignedArea` | `p: PAffineVectorArray; nSides` | `TGeoFloat` | 2D 多边形有符号面积 |
| `SortArrayAscending` | `var a: array of Double` | - | 冒泡排序（升序） |
| `DivMod` | `Dividend: Integer; Divisor: Word; var Result, Remainder: Word` | - | 整数除法及余数 |
| `PointInPolygon` | `var xp,yp: array of TGeoFloat; x,y` | `Boolean` | 点是否在多边形内（射线法） |
| `ConvertRotation` | `Angles: TAffineVector` | `TVector` | 将三个欧拉角转换为绕任意轴的旋转 |
| `RandomPointOnSphere` | `var p: TAffineVector` | - | 在单位球面上生成随机点 |
| `IsNan` | `Value_: Single / Double` | `Boolean` | 判断是否为 NaN |
| `MaxXYZComponent` / `MinXYZComponent` | 向量 | `TGeoFloat` | 取最大/最小分量 |
| `MaxAbsXYZComponent` / `MinAbsXYZComponent` | 向量 | `TGeoFloat` | 取绝对值后的最大/最小分量 |
| `MaxVector` / `MinVector` | 两个向量 | - | 分量取最大/最小（就地） |
| `ScaleAndRound` | `i: Integer; var s: TGeoFloat` | `Integer` | 缩放并四舍五入 |
| `MakeShadowMatrix` | `planePoint, planeNormal, lightPos` | `TMatrix` | 生成阴影投影矩阵 |
| `MakeReflectionMatrix` | `planePoint, planeNormal` | `TMatrix` | 生成反射矩阵 |
| `MakeParallelProjectionMatrix` | `plane: THmgPlane; dir: TVector` | `TMatrix` | 平行投影矩阵 |
| `MoveObjectAround` | `MovingObjectPosition_, MovingObjectUp_, TargetPosition_; pitchDelta, turnDelta` | `TVector` | 绕目标点旋转物体 |
| `AngleBetweenVectors` | `a,b,ACenterPoint` | `TGeoFloat` | 两向量夹角（弧度） |
| `ShiftObjectFromCenter` | `OriginalPosition_, Center_, Distance_, FromCenterSpot_` | `TVector / TAffineVector` | 将物体移近/远离中心 |
| `BarycentricCoordinates` | `v1,v2,v3,p; var u,v` | `Boolean` | 计算重心坐标，返回是否在三角形内 |

---

> 本手册涵盖了 `Z.Geometry.Low` 接口部分所有导出成员。实现细节请参考源码。
