import 'package:cnattendance/data/source/network/model/rules/CompanyRules.dart';
import 'package:cnattendance/model/content.dart';
import 'package:cnattendance/repositories/companyrulerepository.dart';
import 'package:flutter/material.dart';

class CompanyRulesProvider with ChangeNotifier {
  final List<Content> _contentList = [];
  CompanyRuleRepository repository = CompanyRuleRepository();

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  List<Content> get contentList {
    return [..._contentList];
  }

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;

  Future<void> getContent() async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await repository.getContent();

      if (response.data.isNotEmpty) {
        makeRules(response.data);
      } else {
        _contentList.clear();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _hasError = true;
      _errorMessage = e.toString();
      debugPrint('Error loading company rules: ${e.toString()}');
      notifyListeners();
    }
  }

  void makeRules(List<CompanyRules> data) {
    _contentList.clear();
    for (var item in data) {
      _contentList
          .add(Content(title: item.title, description: item.description));
    }
  }
}
