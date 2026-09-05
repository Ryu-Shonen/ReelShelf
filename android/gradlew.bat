@echo off
setlocal
set APP_HOME=%~dp0
set JAR=%APP_HOME%gradle\wrapper\gradle-wrapper.jar
set URL=https://raw.githubusercontent.com/gradle/gradle/v8.11.1/gradle/wrapper/gradle-wrapper.jar
if not exist "%JAR%" (
  echo Gradle wrapper bootstrap: downloading gradle-wrapper.jar ...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing '%URL%' -OutFile '%JAR%'"
  if errorlevel 1 exit /b 1
)
java -classpath "%JAR%" org.gradle.wrapper.GradleWrapperMain %*
endlocal
