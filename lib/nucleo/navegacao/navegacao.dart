import 'package:flutter/material.dart';

void navegarPara(BuildContext context, Widget pagina) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));

void reiniciarCom(BuildContext context, Widget pagina) => Navigator.of(
  context,
).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => pagina), (_) => false);
