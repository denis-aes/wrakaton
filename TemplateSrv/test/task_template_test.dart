import 'dart:convert';
import "package:test/test.dart";
import 'package:embla/http.dart';
import "package:embla/application.dart";
import 'package:embla/http_basic_middleware.dart';
import 'package:embla_trestle/embla_trestle.dart';
import 'package:template_srv/Srv.dart' as Srv;

import './test_data/common_test.dart';
import 'package:srv_base/Models/Users.dart';
import 'package:srv_base/Srv.dart' as base;

main() async {
  Application app;

  final String serverUrl = TestCommon.srvUrl;

  setUpAll(() async {
    List<Bootstrapper> bootstrappers = [
      new DatabaseBootstrapper(
        driver: TestCommon.driver
      ),
      new base.HttpsBootstrapper(
        port: 9090,
        pipeline: pipe(
          LoggerMiddleware, RemoveTrailingSlashMiddleware,
          Route.post('login/', base.JwtLoginMiddleware),
          base.InputParserMiddleware,
          Route.all('users/*', base.JwtAuthMiddleware,
            new base.UserGroupFilter(UserGroup.USER.Str), base.UserIdFilter,
            base.UserService),
          Route.all('templates/*', base.JwtAuthMiddleware,
            new base.UserGroupFilter(UserGroup.USER.Str),
            Srv.TemplateService)
        )
      ),
      new Srv.ActionSrv()
    ];
    app = await Application.boot(bootstrappers);
  });
  tearDownAll(() async {
    await app.exit();
  });

  group("template create: ", () {

    setUpAll(() async {
      await TestCommon.createTestUser();
      await TestCommon.login();
    });

    createTemplate(String header, String description) {
      Map template = {
        'header' : header,
        'description' : description
      };
      return TestCommon.net.Create("$serverUrl/templates", template);
    }

    test("create template", () async {
      Map template = {
        'header' : 'testTemplate1',
        'description' : 'some template'
      };
      var resp = await TestCommon.net.Create("$serverUrl/templates", template);
      resp = JSON.decode(resp);
      expect(resp, allOf([
        containsPair('id', 1),
        containsPair('msg', 'ok')
      ]));
    });

    test("get template with id 1", () async {
      Map resp = await TestCommon.net.Get("$serverUrl/templates/1");
      expect(resp, allOf([
        containsPair('id', 1),
        containsPair('enabled', true)
      ]));
      expect(resp['config'], allOf([
        containsPair('header', 'testTemplate1'),
        containsPair('description', 'some template')
      ]));
    });

    test("get templates", () async {
      List resp = await TestCommon.net.Get("$serverUrl/templates");
      expect(resp.length, 1);
    });

    test("test nested", () async {
      var resp = await createTemplate('nested template', 'some nested template');
      resp = JSON.decode(resp);
      resp = await TestCommon.net.Update("$serverUrl/templates/1/nested", {
        'items' : JSON.encode([resp['id']])
      });
      resp = await TestCommon.net.Get("$serverUrl/templates/1");
      expect(resp['nested'], equals([2]));
    });
  });
}