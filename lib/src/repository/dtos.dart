import 'package:loxia/loxia.dart';

abstract class InsertDto<T extends Entity> {

  Map<String, dynamic> toMap();

}

abstract class UpdateDto<T extends Entity> {
  Map<String, dynamic> toMap();
}