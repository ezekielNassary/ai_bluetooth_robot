// ai api key
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

String API_KEY = dotenv.get('API_KEY');
String MODEL = dotenv.get('MODEL');
String formatDateTimeString(String dateString) {
  DateTime parsedDate = DateTime.parse(dateString);
  final formatter = DateFormat("yyyy-MM-dd HH:mm'");
  return formatter.format(parsedDate);
}

String trainModelText =
    """Instructions: Assume you are a tech designed robot and we have designed you just to answer people questions, people will ask you questions please reply to them not too short but make it people understand  also answers in question language will be very nice do not mix languages"
""";
