// app.js
const express = require('express');
const mongoose = require('mongoose');
const userRoutes = require('./routes/userRoutes'); // Adjust this path if your file structure is different

const app = express();

// Connect to MongoDB
mongoose.connect('mongodb://localhost:27017/mydatabase', {
  useNewUrlParser: true,
  useUnifiedTopology: true
}).then(() => console.log('MongoDB connected...'))
  .catch(err => console.log(err));

// Middleware to parse JSON bodies
app.use(express.json());

// Use routes
app.use(userRoutes);

// Start the server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});


const express = require('express');
const https = require('https');
const fs = require('fs');
const path = require('path');

const app = express();

// Your API routes and middleware here

const options = {
  key: fs.readFileSync(path.join(__dirname, 'key.pem')),
  cert: fs.readFileSync(path.join(__dirname, 'cert.pem'))
};

https.createServer(options, app).listen(3000, () => {
  console.log('HTTPS server running on port 3000');
});
