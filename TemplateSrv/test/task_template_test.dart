import 'dart:async';
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
            Srv.UserService),
          Route.all('templates/*', base.JwtAuthMiddleware,
            new base.UserGroupFilter(UserGroup.USER.Str),
            Srv.TemplateService),
          Route.all('storage/*', Srv.StorageService)
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

    createTemplate(String header,
                   String description,
                   String type,
                   List<String> assignee,
                   List workflow) {
      Map template = {
        'title' : header,
        'description' : description,
        'type' : type,
        'assignee' : JSON.encode(assignee),
        'workflow' : JSON.encode(workflow)
      };
      return TestCommon.net.Create("$serverUrl/templates", template);
    }

    List defWorkflow = [
      { 'state_name' : 'new'},
      {'state_name' : 'in progress'},
      {'state_name' : 'done'}
    ];

    test("create template", () async {
      var resp = await createTemplate('testTemplateTask1',
        'some template of task', 'TASK', ['user_id_1', 'user_id_2'],
        defWorkflow);
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
        containsPair('enabled', true),
        containsPair('type', 'TASK')
      ]));
      expect(resp['data'], allOf([
        containsPair('title', 'testTemplateTask1'),
        containsPair('description', 'some template of task'),
        containsPair('assignee', ['user_id_1', 'user_id_2']),
      ]));
    });

    test("get templates", () async {
      List resp = await TestCommon.net.Get("$serverUrl/templates");
      expect(resp.length, 1);
    });

    test("test nested", () async {
      int baseProjId = null;
      int nestedTemplateId = null;
      var resp = await createTemplate('base project template',
        'some project template', 'PROJECT', [],
        defWorkflow);
      baseProjId = JSON.decode(resp)['id'];

      resp = await createTemplate('testTemplateTask1',
        'some template of task', 'TASK', ['user_id_1', 'user_id_2'],
        defWorkflow);

      nestedTemplateId = JSON.decode(resp)['id'];
      resp = await TestCommon
        .net.Update("$serverUrl/templates/${baseProjId}/nested", {
        'items' : JSON.encode([nestedTemplateId])
      });
      resp = await TestCommon.net.Get("$serverUrl/templates/${baseProjId}");
      expect(resp['nested'], equals([nestedTemplateId]));
    });

    test("get deep reprezentation", () async {
      Map resp = await TestCommon.net.Get("$serverUrl/templates/2?full");
      expect(resp['nested'], isList);
      for(var el in resp['nested']) {
        expect(el, isMap);
        expect(el, contains('id'));
      }
      print('----full-representation--');
      print(resp);
      print('-------------------------');
    });

    test("get all templates", () async {
      List resp = await TestCommon.net.Get("$serverUrl/templates");
      expect(resp, isList);
      print('----full-representation--');
      print(resp);
      print('-------------------------');
    });

    test('deploy template', () async {
      Map params = {'template' : 2};
      var resp = await TestCommon
        .net.Create("$serverUrl/${TestCommon.userUrl}/templates", params);
      print(resp);
      await new Future.delayed(new Duration(seconds: 1));
    });

  });

  group("storage test: ", () {

    setUpAll(() async {
      await TestCommon.login();
    });

    test("forms data", () async {
      var resp = await TestCommon.net.Create("$serverUrl/storage/forms",
        { 'id' : 1002, 'data' : JSON.encode({ 'hello' : 'world'}) });
      resp = await TestCommon.net.Get("$serverUrl/storage/forms/1002");
      print(resp);
    });

    test("tasks data", () async {
      var resp = await TestCommon.net.Create("$serverUrl/storage/tasks",
        { 'id' : 1002, 'data' : JSON.encode({ 'hello' : 'world'}) });
      resp = await TestCommon.net.Get("$serverUrl/storage/tasks/1002");
      print(resp);
    });
  });
}
