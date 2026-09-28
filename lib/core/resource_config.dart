class FieldDef {
  const FieldDef(this.key, this.label, {this.numeric=false, this.required=false, this.defaultValue=''});
  final String key, label, defaultValue; final bool numeric, required;
}
class ResourceDef {
  const ResourceDef(this.id,this.title,this.fields,this.columns);
  final String id,title; final List<FieldDef> fields; final List<String> columns;
}
const resources = <String,ResourceDef>{
  'mandi-purchases': ResourceDef('mandi-purchases','Mandi Purchase',[
    FieldDef('date','Date',required:true), FieldDef('vendor','Mandi/Vendor',required:true), FieldDef('item','Item',required:true),
    FieldDef('specification','Specification'),
    FieldDef('quantity_value','Quantity',numeric:true,required:true), FieldDef('quantity_unit','Unit',defaultValue:'Kg'), FieldDef('rate','Rate',numeric:true,required:true),
  ],['date','vendor','item','specification','quantity_value','quantity_unit','rate','amount']),
  'local-purchases': ResourceDef('local-purchases','Local Purchase',[
    FieldDef('date','Date',required:true), FieldDef('vendor','Vendor/Farmer',required:true), FieldDef('item','Item',required:true),
    FieldDef('specification','Specification'),
    FieldDef('quantity_value','Quantity',numeric:true,required:true), FieldDef('quantity_unit','Unit',defaultValue:'Kg'), FieldDef('rate','Rate',numeric:true,required:true),
  ],['date','vendor','item','specification','quantity_value','quantity_unit','rate','amount']),
  'stock': ResourceDef('stock','Stock / Inventory',[
    FieldDef('item','Item',required:true), FieldDef('specification','Specification'), FieldDef('qty','Qty (Kg)',numeric:true,required:true),
    FieldDef('avg_cost','Avg Cost',numeric:true), FieldDef('selling_price','Selling Price',numeric:true), FieldDef('status','Status',defaultValue:'Available'),
  ],['item','specification','qty','avg_cost','selling_price','status']),
  'sales': ResourceDef('sales','Sales / Supply',[
    FieldDef('date','Date',required:true), FieldDef('customer','Customer',required:true), FieldDef('phone','Phone'), FieldDef('item','Item',required:true),
    FieldDef('specification','Specification'),
    FieldDef('quantity_value','Quantity',numeric:true,required:true), FieldDef('quantity_unit','Unit',defaultValue:'Kg'), FieldDef('rate','Rate',numeric:true,required:true),
    FieldDef('payment_method','Payment Method',defaultValue:'Cash'), FieldDef('transaction_id','Transaction ID'),
    FieldDef('status','Status',defaultValue:'Due'),
  ],['date','customer','item','specification','quantity_value','quantity_unit','rate','amount','payment_method','status']),
  'customers': ResourceDef('customers','Customers',[
    FieldDef('name','Customer Name',required:true), FieldDef('phone','Phone'), FieldDef('due','Due',numeric:true), FieldDef('business','Business',numeric:true), FieldDef('due_date','Due Date'), FieldDef('status','Status',defaultValue:'Upcoming'),
  ],['name','phone','due','business','due_date','status']),
  'payments': ResourceDef('payments','Payments & Due',[
    FieldDef('customer','Customer Name',required:true), FieldDef('phone','Phone'), FieldDef('date','Date',required:true), FieldDef('amount','Amount',numeric:true,required:true),
    FieldDef('payment_method','Payment Method',defaultValue:'Cash'), FieldDef('transaction_id','Transaction ID'),
    FieldDef('note','Note'),
  ],['date','customer','phone','amount','payment_method','type','note']),
  'expenses': ResourceDef('expenses','Expenses',[
    FieldDef('date','Date',required:true), FieldDef('category','Category',required:true), FieldDef('note','Note'), FieldDef('amount','Amount',numeric:true,required:true),
  ],['date','category','note','amount']),
  'labour': ResourceDef('labour','Labour / Majdoor',[
    FieldDef('date','Date',required:true), FieldDef('name','Name',required:true), FieldDef('work_type','Work Type',required:true), FieldDef('workers','Workers',numeric:true,required:true), FieldDef('amount','Amount',numeric:true,required:true),
  ],['date','name','work_type','workers','amount']),
  'whatsapp-bills': ResourceDef('whatsapp-bills','WhatsApp Bills',[],['customer','phone','amount','date','kind','status']),
  'notifications': ResourceDef('notifications','Notifications',[],['text','time','read','action_message']),
};
