-- Adminer 4.2.0 MySQL dump

SET NAMES utf8mb4;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;
SET sql_mode = 'NO_AUTO_VALUE_ON_ZERO';

DROP DATABASE IF EXISTS `QVS`;
CREATE DATABASE `QVS` /*!40100 DEFAULT CHARACTER SET utf8 */;
USE `QVS`;

DROP TABLE IF EXISTS `DATABASE_CONNECTIONS`;
CREATE TABLE `DATABASE_CONNECTIONS` (
  `JDBCINFO` int(11) NOT NULL,
  `KEY` varchar(255) NOT NULL,
  `USERNAME` varchar(255) NOT NULL,
  `PASSWORD` varchar(255) NOT NULL,
  `DATABASE` varchar(255) NOT NULL,
  `HOST` varchar(255) NOT NULL,
  `PORT` varchar(5) NOT NULL,
  `USER` bigint(20) NOT NULL,
  PRIMARY KEY (`KEY`,`USER`),
  KEY `USER_idx` (`USER`),
  CONSTRAINT `USER` FOREIGN KEY (`USER`) REFERENCES `USERS` (`ID`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `FILTERS`;
CREATE TABLE `FILTERS` (
  `KEY` varchar(45) NOT NULL,
  `QUERY` text NOT NULL,
  `USER` bigint(20) NOT NULL,
  `DB_KEY` varchar(45) NOT NULL,
  PRIMARY KEY (`KEY`,`USER`),
  KEY `USER_idx` (`DB_KEY`),
  KEY `UID_idx` (`USER`),
  CONSTRAINT `DB` FOREIGN KEY (`DB_KEY`) REFERENCES `DATABASE_CONNECTIONS` (`KEY`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `UID` FOREIGN KEY (`USER`) REFERENCES `USERS` (`ID`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `QUERIES`;
CREATE TABLE `QUERIES` (
  `KEY` varchar(45) NOT NULL,
  `USER` bigint(20) NOT NULL,
  `USERNAME` varchar(255) NOT NULL,
  `PASSWORD` varchar(255) NOT NULL,
  `JDBCINFO` int(11) NOT NULL,
  `DATABASE_NAME` varchar(255) NOT NULL,
  `HOST` varchar(255) NOT NULL,
  `PORT` int(11) NOT NULL,
  `USE_CACHE` varchar(1) DEFAULT '0',
  `QUERY_STATEMENT` text NOT NULL,
  `MODIFICATION_TYPE` int(11) NOT NULL,
  `VISUALIZATION_TYPE` int(11) NOT NULL,
  `VISUALIZATION_TITLE` varchar(255) DEFAULT NULL,
  `VISUALIZATION_HEIGHT` int(11) DEFAULT NULL,
  `VISUALIZATION_WIDTH` int(11) DEFAULT NULL,
  PRIMARY KEY (`KEY`,`USER`),
  KEY `fk_QUERIES_1_idx` (`USER`),
  CONSTRAINT `fk_QUERIES_1` FOREIGN KEY (`USER`) REFERENCES `USERS` (`ID`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


DROP TABLE IF EXISTS `USERS`;
CREATE TABLE `USERS` (
  `ID` bigint(20) NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


-- 2015-02-16 16:02:35