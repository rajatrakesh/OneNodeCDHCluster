# IBM Cloud setup notes

Login into CDSW, go to Admin > Engines and add the following

- to **Environmental variables**:

```
HADOOP_CONF_DIR   /etc/hadoop/conf/
SPARK_CONF_DIR    /etc/spark/conf/
```

- to **Mounts**, with *Write Access* checked:

```
/etc/hadoop/conf
/etc/spark/conf
```
