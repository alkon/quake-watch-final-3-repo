# Define Python version arguments
ARG PYTHON_VER=3.13
ARG PYTHON_SUB_VER=2

# Use the Python version argument to select the base image
FROM python:${PYTHON_VER}.${PYTHON_SUB_VER}-alpine AS builder

# Set the working directory inside the container
# This means /app will be the root of your Python project within the container
WORKDIR /app

RUN apk update && \
    apk add --no-cache \
    python3 \
    py3-pip && \
    # Remove cache to reduce size
    rm -rf /var/cache/apk/*

# Copy only requirements.txt first for efficient caching
COPY requirements.txt .

# Install dependencies without caching
RUN pip install --no-cache-dir -r requirements.txt

# Final stage to reduce image size
FROM python:${PYTHON_VER}.${PYTHON_SUB_VER}-alpine AS final
WORKDIR /app
ARG PYTHON_VER

# Install curl in the final stage (for healthcheck from inside the container)
RUN apk update && \
    apk add --no-cache curl

# Copy the installed Python packages from the builder stage
COPY --from=builder /usr/local/lib/python${PYTHON_VER}/site-packages /usr/local/lib/python${PYTHON_VER}/site-packages

# Copy the entire 'app' directory from the host into the container's /app working directory
# This single command now copies all your Python files, scripts, static, and templates.
COPY app/ .

# Ensure scripts within the 'scripts' directory are executable if needed
# You might need to adjust this based on specific scripts or if they are called by Python
# RUN chmod +x scripts/*.sh

# Expose the port your application will run on
EXPOSE 5000

# Define the command to run your application
# Assuming 'app.py' within the 'app' directory is the main entry point
CMD ["python", "app.py"]