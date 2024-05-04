// userRoutes.js
const express = require('express');
const User = require('../models/User'); // Adjust this path based on where your User model is stored
const auth = require('../middleware/auth'); // Ensure the path to auth middleware is correct
const router = express.Router();

// Example of a protected route that retrieves user profile information
router.get('/profile', auth, (req, res) => {
  res.send({ profile: req.user });
});

module.exports = router;

const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const router = express.Router();

// POST /users/register - Register a new user
router.post('/users/register', async (req, res) => {
    try {
        // Hash password before saving to database
        const hashedPassword = await bcrypt.hash(req.body.password, 8);

        // Create a new user
        const user = new User({
            username: req.body.username,
            email: req.body.email,
            password: hashedPassword
        });

        await user.save();

        // Create a token for the user
        const token = jwt.sign({ _id: user._id.toString() }, 'your_secret_key');

        res.status(201).send({ user, token });
    } catch (error) {
        res.status(400).send(error);
    }
});

module.exports = router;

// POST /users/login - Login a user
router.post('/users/login', async (req, res) => {
    try {
        const user = await User.findOne({ email: req.body.email });
        if (!user) {
            return res.status(404).send('Unable to login');
        }

        const isMatch = await bcrypt.compare(req.body.password, user.password);
        if (!isMatch) {
            return res.status(400).send('Unable to login');
        }

        const token = jwt.sign({ _id: user._id.toString() }, 'your_secret_key');
        res.send({ user, token });
    } catch (error) {
        res.status(500).send();
    }
});


// POST /users/transaction - Perform a transaction
router.post('/users/transaction', auth, async (req, res) => {
    try {
        const sender = req.user;
        const receiver = await User.findOne({ email: req.body.email });
        const amount = req.body.amount;

        if (!receiver || amount <= 0) {
            return res.status(400).send('Invalid transaction');
        }

        if (sender.balance < amount) {
            return res.status(400).send('Insufficient balance');
        }

        sender.balance -= amount;
        receiver.balance += amount;

        await sender.save();
        await receiver.save();

        res.send({ sender, receiver });
    } catch (error) {
        res.status(500).send(error);
    }
});

const Joi = require('joi');

// Define schema for user registration
const userSchema = Joi.object({
    username: Joi.string().alphanumeric().min(3).max(30).required(),
    email: Joi.string().email().required(),
    password: Joi.string().pattern(new RegExp('^[a-zA-Z0-9]{3,30}$')),
    repeat_password: Joi.ref('password'),
});

router.post('/users/register', async (req, res) => {
    try {
        // Validate request data
        const { error, value } = userSchema.validate(req.body);
        if (error) {
            return res.status(400).send(error.details[0].message);
        }

        // Proceed with user registration...
    } catch (error) {
        res.status(500).send("Internal Server Error");
    }
});


// Import necessary modules
const express = require('express');
const router = express.Router();

// Define a route to handle GET requests
router.get('/api/users', (req, res) => {
    // Logic to retrieve users from the database
    // Send response with users data
    res.json({ message: 'Get all users' });
});

// Export the router
module.exports = router;


