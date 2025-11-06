# Outlook Mail Classifier

This is a Flutter application designed to help users efficiently manage their Outlook inbox by automatically categorizing emails and providing tools for bulk actions.

## Business Functionality

The core purpose of this application is to streamline email management for Outlook users. It achieves this through the following features:

1.  **Secure Authentication:**
    *   Users log in securely using their Microsoft Outlook accounts, powered by the Microsoft Authentication Library (`msal_flutter`).
    *   The application uses OAuth 2.0 to obtain an access token, ensuring that user credentials are never stored or handled directly by the app.

2.  **Automatic Email Categorization:**
    *   Upon logging in, the application fetches the user's emails and automatically sorts them into three predefined categories:
        *   **Social Media:** Emails from major social platforms (e.g., Facebook, Twitter) are grouped together.
        *   **Promotions:** Emails identified as promotional content are filtered into this category.
        *   **Other:** All other emails fall into this general category, helping to separate important messages from clutter.

3.  **Bulk Email Management:**
    *   Within each category, users can select multiple emails at once.
    *   The application provides two options for handling selected emails:
        *   **Move to Deleted Items:** Safely moves unwanted emails to the "Deleted Items" folder in Outlook.
        *   **Permanently Delete:** Allows for the immediate and permanent removal of emails, freeing up space.

This tool is ideal for users who receive a high volume of emails and want a simple, mobile-first way to clean up their inbox.

