import 'package:cnattendance/provider/companyrulesprovider.dart';
import 'package:cnattendance/widget/companyrulesscreen/rulescardview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RulesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CompanyRulesProvider>(context);
    final rulesList = provider.contentList;
    final isLoading = provider.isLoading;
    final hasError = provider.hasError;
    final errorMessage = provider.errorMessage;

    // Show loading state
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading company rules...',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      );
    }

    // Show error state
    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text('Failed to load company rules',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            SizedBox(height: 8),
            Text(errorMessage,
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Provider.of<CompanyRulesProvider>(context, listen: false)
                    .getContent();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show empty state if no rules
    if (rulesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text('No company rules found',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Provider.of<CompanyRulesProvider>(context, listen: false)
                    .getContent();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
        itemCount: rulesList.length,
        itemBuilder: (ctx, i) {
          return RulesCardView(rulesList[i].title, rulesList[i].description);
        });
  }
}
