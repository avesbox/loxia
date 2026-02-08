---
title: Loxia - Lightweight ORM for Dart
titleTemplate: false
layout: page
sidebar: false
---

<script setup>
  import Home from './components/home/home.vue';
</script>

<Home>
  <template #start>

:::code-group

```dart canary [Entrypoint]
import 'package:serinus/serinus.dart';

Future<void> main() async {
  final app = await serinus.createApplication(
    entrypoint: AppModule(),
  );
  await app.serve();
}
```

```dart canary [Module]
import 'package:serinus/serinus.dart';

import 'app_controller.dart';

class AppModule extends Module {
  AppModule() : super(
    controllers: [AppController()],
  );
}
```

```dart canary [Controller]
import 'package:serinus/serinus.dart';

class AppController extends Controller {

  AppController() : super('/') {
    on(Route.get('/'), _handleHelloWorld);
  }

  String _handleHelloWorld(RequestContext context) {
    return 'Hello, World!';
  }
}
```

:::

  </template>
</Home>
