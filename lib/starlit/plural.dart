String starlitPlural(int n, String one, String few, String many) {
  final mod100 = n.abs() % 100;
  final mod10 = n.abs() % 10;
  if (mod100 > 10 && mod100 < 20) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

const _months = <String>[
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String starlitDayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String starlitDayMonthTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${starlitDayMonth(d)}, $hh:$mm';
}
