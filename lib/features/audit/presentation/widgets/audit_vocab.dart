/// Mongolian labels for the Audit vocab chips — measured against
/// `carcare.mn`'s `app/dashboard/audit/page.tsx` (`ACTION_LABEL`,
/// `ENTITY_LABEL`) so the mobile filter sheet reads identically to the web
/// one. A value not in this map (a future action/entity the web has not
/// added a label for yet) falls back to the raw wire string rather than
/// throwing or hiding the chip.
library;

const Map<String, String> auditActionLabels = {
  'CREATE': 'Үүсгэсэн',
  'UPDATE': 'Шинэчлэсэн',
  'DELETE': 'Устгасан',
  'STATUS_CHANGE': 'Статус',
  'PAYMENT_CHANGE': 'Төлбөр',
  'STOCK_CHANGE': 'Нөөц',
  'ITEM_ADDED': 'Мөр нэмсэн',
  'ITEM_REMOVED': 'Мөр устгасан',
  'ITEM_UPDATED': 'Мөр зассан',
  'ITEM_CANCELLED': 'Мөр цуцалсан',
  'ITEM_STATUS_CHANGE': 'Мөрийн явц',
  'LOGIN': 'Нэвтэрсэн',
  'LOGOUT': 'Гарсан',
  'OTHER': 'Бусад',
};

const Map<String, String> auditEntityLabels = {
  'ServiceOrder': 'Засварын хуудас',
  'Service': 'Үйлчилгээ',
  'Customer': 'Үйлчлүүлэгч',
  'Vehicle': 'Машин',
  'User': 'Ажилтан',
  'Branch': 'Салбар',
  'Category': 'Ангилал',
  'Unit': 'Нэгж',
  'Tenant': 'Байгууллага',
  'Role': 'Үүрэг',
  'DiagnosticTemplate': 'Оношилгооны загвар',
  'DiagnosticReport': 'Оношилгооны тайлан',
  'Appointment': 'Цаг захиалга',
  'Notification': 'Мэдэгдэл',
};

String auditActionLabel(String value) => auditActionLabels[value] ?? value;

String auditEntityLabel(String value) => auditEntityLabels[value] ?? value;
