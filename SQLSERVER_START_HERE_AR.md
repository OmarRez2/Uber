# تشغيل مشروع Uber على SQL Server

تم إعداد المشروع للعمل على Microsoft SQL Server Express المحلي.

## بيانات الاتصال

- Server name: `.\SQLEXPRESS`
- Authentication: `Windows Authentication`
- Database: `Uber`

## الاستيراد لأول مرة

اعمل Double-click على الملف:

`Import_Uber_To_SQLServer.bat`

الملف ينشئ قاعدة البيانات والجداول والـViews، ثم يستورد البيانات ويختبر جميع الاستعلامات. إذا كانت البيانات مستوردة بالفعل، فلن يكرر الصفوف وسيشغل التحقق فقط.

## فتح المشروع في SSMS

1. افتح SQL Server Management Studio.
2. اكتب `.\SQLEXPRESS` في Server name.
3. اختر Windows Authentication ثم Connect.
4. من Databases افتح `Uber`.
5. افتح `Uber_Insights_Queries_SQLServer.sql`.
6. اختر Execute أو اضغط `F5`.

يمكنك أيضًا بدء Query جديدة وتجربة:

```sql
USE Uber;
GO

SELECT TOP (100) *
FROM dbo.trips;
```

## الجداول والـViews

- `dbo.trip_details`: بيانات الرحلات الخام، 103,728 صفًا.
- `dbo.location_table`: أسماء المواقع، 265 صفًا.
- `dbo.official_taxi_zones`: مرجع المناطق الرسمي، 265 صفًا.
- `dbo.trips`: View جاهزة للتحليل وتحتوي حقول المدة والسرعة والتاريخ واليوم.
- `dbo.locations`: View مبسطة للمواقع.

استخدم `dbo.trips` و`dbo.locations` في استعلامات التحليل.
