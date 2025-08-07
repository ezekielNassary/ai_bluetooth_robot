// ai api key
import 'package:intl/intl.dart';

String API_KEY = 'AIzaSyDjAepH9MO7mMtwivFscaZiQHQPo1WbXs8';
String MODEL = 'gemini-1.5-flash-latest';

String formatDateTimeString(String dateString) {
  DateTime parsedDate = DateTime.parse(dateString);
  final formatter = DateFormat("yyyy-MM-dd HH:mm'");
  return formatter.format(parsedDate);
}

String trainModelText =
    """Instructions: Assume you are a tech designed robot and we have designed you just to answer people questions, people will ask you questions please reply to them not too short but make it people understand  also answers in question language will be very nice do not mix languages"
""";
