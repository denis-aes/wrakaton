import 'dart:async';
import 'package:embla/application.dart';
import 'package:embla/http.dart';
import 'package:embla_trestle/embla_trestle.dart';
import 'package:srv_base/Utils/Utils.dart';
import 'package:srv_base/Utils/Crypto.dart' as crypto;
import 'package:template_srv/Models/Template.dart';
import 'package:template_srv/Services/UsersService.dart' show User, UserGroup;
import 'dart:convert';

class SubDeploy extends Bootstrapper {
  static List defWorkflow =  [
     { 'state_name' : 'New', 'to_states' : [1, 2],
       'enter_actions' : [],
       'leave_actions' : []
     },
     { 'state_name' : 'In progress', 'to_states' : [0, 2, 3],
       'enter_actions' : [],
       'leave_actions' : []
     },
     { 'state_name' : 'Wait', 'to_states' : [1],
       'enter_actions' : [],
       'leave_actions' : []
     },
     { 'state_name' : 'Done', 'to_states' : [0],
       'enter_actions' : [],
       'leave_actions' : []
     },
  ];

  final Gateway gateway;
  Repository<User> _users;
  Repository<Template> _templates;

  SubDeploy(this.gateway);

  @Hook.init
  init() {
    _users = new Repository<User>(gateway);
    _templates = new Repository<Template>(gateway);
    createStubUser();
    createStubTemplates();
  }

  Future<int> createTemplate(String header,
                             String description,
                             String type,
                             List<String> assignee,
                             List<int> nested,
                             List workflow,
                             [String placeId = null]) {
    Map template = {
      'title' : header,
      'description' : description,
      'type' : type,
      'place' : placeId,
      'assignee' : JSON.encode(assignee),
      'nested' : JSON.encode(nested),
      'workflow' : JSON.encode(workflow)
    };
    return _createTemplate(template);
  }

  Future<int> _createTemplate(Map params) async {
    Template template = new Template()
      ..enabled = true
      ..TType = TemplateType.fromStr(params['type'])
      ..data = {
        'title' : params['title'],
        'description' : params['description'],
        'assignee' : JSON.decode(params['assignee']),
        'workflow' : JSON.decode(params['workflow'])
      };
    if(params.containsKey('nested')) {
      template.nested = JSON.decode(params['nested']);
    } else {
      template.nested = [];
    }
    await _templates.save(template);
    return template.id;
  }

  createStubUser() async {
    User user = new User()
      ..email = "wrakatoner@team.wrike.com"
      ..password =  crypto.encryptPassword('wrakaton')
      ..enabled = true
      ..group = UserGroup.toStr(UserGroup.USER)
      ..data = {}
      ..settings = {};
    _users.save(user);
  }

  createStubTemplates() async {
    {
      List<int> nested = [
      await createTemplate('base task template',
        'some task template', 'TASK', [], [], defWorkflow),
      await createTemplate('base task template',
        'some task template', 'TASK', [], [], defWorkflow)
      ];
      await createTemplate('base project template',
        'some project template', 'PROJECT', [], nested, defWorkflow, 'megaTeemId');
    }
  }

}