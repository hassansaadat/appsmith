#!/bin/bash
set -e

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
until mongosh --host mongodb -u $MONGO_ROOT_USER -p $MONGO_ROOT_PASSWORD \
  --authenticationDatabase admin --eval "db.runCommand('ping').ok" --quiet; do
  sleep 2
done

# Initialize replica set (if not already initialized)
echo "Initializing replica set..."
mongosh --host mongodb -u $MONGO_ROOT_USER -p $MONGO_ROOT_PASSWORD \
  --authenticationDatabase admin --eval "
  try {
    if (!rs.status().ok) {
      rs.initiate({
        _id: 'rs0',
        members: [{ _id: 0, host: 'mongodb:27017' }],
        settings: { heartbeatTimeoutSecs: 2 }
      });
      console.log('Replica set initialized');
    } else {
      console.log('Replica set already initialized');
    }
  } catch (e) {
    console.error('Replica set initialization error:', e);
    throw e;
  }
"

# Create application user
echo "Creating application user..."
mongosh --host mongodb -u $MONGO_ROOT_USER -p $MONGO_ROOT_PASSWORD \
  --authenticationDatabase admin --eval "
  db = db.getSiblingDB('admin');
  try {
    db.createUser({
      user: '$MONGO_APP_USER',
      pwd: '$MONGO_APP_PASSWORD',
      roles: [
        { role: 'readWrite', db: '$MONGO_APP_DATABASE' },
        { role: 'clusterMonitor', db: 'admin' }
      ]
    });
    console.log('User created successfully');
  } catch (e) {
    if (e.codeName === 'DuplicateKey') {
      console.log('User already exists');
    } else {
      console.error('User creation error:', e);
      throw e;
    }
  }
"

echo "MongoDB initialization complete!"
