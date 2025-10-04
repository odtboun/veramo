# Veramo Widget

This widget shows your partner's latest calendar update on your home screen.

## Features

- Shows partner's most recent calendar entry (not future dates)
- Displays the image with a beautiful UI
- Updates automatically every hour
- Shows when the last update was made

## Setup Instructions

### 1. Add Widget Extension to Xcode

1. Open your Xcode project
2. Go to **File > New > Target**
3. Select **Widget Extension**
4. Name it `VeramoWidget`
5. Make sure "Include Configuration Intent" is **unchecked**
6. Click **Finish**

### 2. Replace Generated Files

Replace the generated widget files with the ones in this folder:

- `VeramoWidget.swift` - Main widget implementation
- `VeramoWidgetBundle.swift` - Widget bundle
- `SharedSupabaseService.swift` - Shared service for Supabase
- `Info.plist` - Widget configuration

### 3. Add Supabase Dependency

1. Select your widget target
2. Go to **General > Frameworks, Libraries, and Embedded Content**
3. Click **+** and add **Supabase** (same as main app)

### 4. Configure App Groups (Optional)

For better data sharing between app and widget:

1. Add App Groups capability to both targets
2. Use a shared container for data storage

## Widget Features

### UI Components
- **Partner Name**: Shows "Partner" with heart emoji
- **Image Display**: Shows partner's latest calendar image
- **Date Info**: Shows when the last update was made
- **Loading State**: Shows progress indicator while loading

### Data Source
- Fetches from `calendar_entries` table
- Filters by partner's user ID
- Only shows entries from today or earlier (no future dates)
- Orders by most recent first

### Update Schedule
- Updates every hour automatically
- Can be refreshed manually by user
- Shows loading state during updates

## Customization

You can customize the widget by modifying:

- **Widget Size**: Currently set to `.systemSmall` (square format)
- **Update Frequency**: Change the timeline policy
- **UI Design**: Modify the `VeramoWidgetEntryView`
- **Data Source**: Adjust the `fetchPartnerUpdate()` function

## Testing

1. Build and run the widget target
2. Add the widget to your home screen
3. Test with different partner scenarios:
   - No partner connected
   - Partner with no entries
   - Partner with recent entries
   - Network errors

## Troubleshooting

### Common Issues

1. **Widget not showing data**: Check Supabase connection and authentication
2. **Images not loading**: Verify storage bucket permissions
3. **Update frequency**: Widget updates are limited by iOS (every 15 minutes minimum)

### Debug Tips

- Check Xcode console for widget logs
- Test with different network conditions
- Verify partner connection status
- Check Supabase RLS policies
