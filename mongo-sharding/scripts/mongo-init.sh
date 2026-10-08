#!/bin/bash

###
# Инициализируем шардированный кластер MongoDB
###

# 1. Инициализируем реплика-сет config server
docker compose exec -T configSrv mongosh --port 27017 --quiet --eval '
  rs.initiate({
    _id: "config_server",
    configsvr: true,
    members: [{ _id: 0, host: "configSrv:27017" }]
  })
'

# 2. Инициализируем реплика-сет shard1
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval '
  rs.initiate({
    _id: "shard1",
    members: [{ _id: 0, host: "shard1:27018" }]
  })
'

# 3. Инициализируем реплика-сет shard2
docker compose exec -T shard2 mongosh --port 27019 --quiet --eval '
  rs.initiate({
    _id: "shard2",
    members: [{ _id: 0, host: "shard2:27019" }]
  })
'

# Даём реплика-сетам время выбрать PRIMARY
sleep 10

# 4. Регистрируем шарды в роутере mongos
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval '
  sh.addShard("shard1/shard1:27018");
  sh.addShard("shard2/shard2:27019");
'

# 5. Включаем шардирование базы и коллекции, наполняем данными
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { name: "hashed" })
use somedb
for (var i = 0; i < 2000; i++) db.helloDoc.insertOne({ age: i, name: "ly" + i })
EOF
