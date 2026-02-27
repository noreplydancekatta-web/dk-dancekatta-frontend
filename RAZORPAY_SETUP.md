# Razorpay Integration Setup Guide

## 🚀 Quick Setup Instructions

### 1. Backend Setup (Node.js)

```bash
# Navigate to backend directory
cd razorpay_backend

# Install dependencies
npm install

# Start server
npm start
```

Server will run on `http://localhost:5000`

### 2. Flutter App Setup

```bash
# Get Flutter dependencies
flutter pub get

# Run on Android emulator
flutter run
```

### 3. Testing the Integration

1. **Start Backend**: Run `npm start` in `razorpay_backend` folder
2. **Start Flutter App**: Run `flutter run`
3. **Navigate to Demo**: Add this to any screen to test:

```dart
ElevatedButton(
  onPressed: () => Navigator.pushNamed(context, '/payment-demo'),
  child: Text('Test Payment'),
)
```

## 🔧 Configuration Details

### Backend Configuration
- **Test Keys**: Already configured in `.env`
- **Port**: 5000 (configurable in `.env`)
- **CORS**: Enabled for Flutter app

### Flutter Configuration
- **Base URL**: `http://10.0.2.2:5000` (for Android emulator)
- **Dependencies**: `razorpay_flutter: ^1.3.7` added to pubspec.yaml

## 📱 Testing Payment

### Test Credentials
- **Card Number**: 4111 1111 1111 1111
- **CVV**: Any 3 digits
- **Expiry**: Any future date
- **UPI ID**: success@razorpay

### Payment Flow
1. Click "Pay Now" → Creates order on backend
2. Opens Razorpay checkout → User pays
3. Payment success → Verifies signature on backend
4. Shows success/failure message

## 🌐 Production Deployment

### 1. VPS Deployment
```bash
# Upload backend to VPS
scp -r razorpay_backend user@your-vps:/path/to/app

# On VPS
cd /path/to/app
npm install
npm start
```

### 2. Update Flutter App
In `lib/services/razorpay_service.dart`:
```dart
// Change this line:
static const String baseUrl = 'http://10.0.2.2:5000';
// To:
static const String baseUrl = 'https://your-vps-domain.com';
```

### 3. Switch to Live Keys
In `razorpay_backend/.env`:
```env
RAZORPAY_KEY_ID=rzp_live_YOUR_LIVE_KEY
RAZORPAY_KEY_SECRET=YOUR_LIVE_SECRET
```

## 🔒 Security Notes

- Never expose secret keys in frontend
- Always verify payments on backend
- Use HTTPS in production
- Validate all payment data

## 📋 Integration Checklist

- [x] Backend APIs created (`/create-order`, `/verify-payment`)
- [x] Flutter Razorpay SDK integrated
- [x] Payment service created
- [x] UI screens implemented
- [x] Android permissions configured
- [x] Test credentials provided
- [x] Error handling implemented
- [x] Success/failure callbacks handled

## 🚨 Troubleshooting

### Common Issues:
1. **Network Error**: Check if backend is running on port 5000
2. **Payment Fails**: Verify test credentials
3. **Android Issues**: Ensure `usesCleartextTraffic="true"` in AndroidManifest.xml
4. **Emulator Issues**: Use `10.0.2.2:5000` instead of `localhost:5000`

### Debug Steps:
1. Check backend logs for API calls
2. Verify network connectivity
3. Test with different payment methods
4. Check Flutter console for errors

## 📞 Support
- Razorpay Docs: https://razorpay.com/docs/
- Flutter Plugin: https://pub.dev/packages/razorpay_flutter