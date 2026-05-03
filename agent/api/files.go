package api

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

const maxFileSize = 10 * 1024 * 1024 // 10MB

// FileInfo represents file or directory information
type FileInfo struct {
	Name    string `json:"name"`
	Path    string `json:"path"`
	Size    int64  `json:"size"`
	IsDir   bool   `json:"isDir"`
	ModTime string `json:"modTime"`
	Mode    string `json:"mode"`
}

// FilesResponse wraps the list of files
type FilesResponse struct {
	Path  string     `json:"path"`
	Files []FileInfo `json:"files"`
}

// FileReadResponse represents file content
type FileReadResponse struct {
	Path    string `json:"path"`
	Content string `json:"content"`
	Size    int64  `json:"size"`
}

// FileWriteRequest represents a file write request
type FileWriteRequest struct {
	Path    string `json:"path"`
	Content string `json:"content"`
}

// GetFiles handles file operations based on the action parameter
func GetFiles(w http.ResponseWriter, r *http.Request) {
	action := r.URL.Query().Get("action")
	
	switch action {
	case "read":
		readFile(w, r)
	case "write":
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed for write action", http.StatusMethodNotAllowed)
			return
		}
		writeFile(w, r)
	default:
		// Default action is browse/list
		listFiles(w, r)
	}
}

// listFiles lists files in a directory
func listFiles(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	dirPath := r.URL.Query().Get("path")
	if dirPath == "" {
		dirPath = "/"
	}

	// Security check: ensure path exists and is accessible
	absPath, err := filepath.Abs(dirPath)
	if err != nil {
		log.Printf("[ERROR] Invalid path %s: %v", dirPath, err)
		http.Error(w, "Invalid path", http.StatusBadRequest)
		return
	}

	// Check if path exists
	info, err := os.Stat(absPath)
	if err != nil {
		log.Printf("[ERROR] Failed to stat path %s: %v", absPath, err)
		http.Error(w, fmt.Sprintf("Path not found: %v", err), http.StatusNotFound)
		return
	}

	// If it's a file, return single file info
	if !info.IsDir() {
		fileInfo := FileInfo{
			Name:    filepath.Base(absPath),
			Path:    absPath,
			Size:    info.Size(),
			IsDir:   false,
			ModTime: info.ModTime().Format(time.RFC3339),
			Mode:    info.Mode().String(),
		}
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(FilesResponse{
			Path:  absPath,
			Files: []FileInfo{fileInfo},
		})
		return
	}

	// List directory contents
	entries, err := os.ReadDir(absPath)
	if err != nil {
		log.Printf("[ERROR] Failed to read directory %s: %v", absPath, err)
		http.Error(w, fmt.Sprintf("Failed to read directory: %v", err), http.StatusInternalServerError)
		return
	}

	var files []FileInfo
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			continue
		}

		files = append(files, FileInfo{
			Name:    entry.Name(),
			Path:    filepath.Join(absPath, entry.Name()),
			Size:    info.Size(),
			IsDir:   entry.IsDir(),
			ModTime: info.ModTime().Format(time.RFC3339),
			Mode:    info.Mode().String(),
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(FilesResponse{
		Path:  absPath,
		Files: files,
	})
}

// readFile reads and returns file content
func readFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	filePath := r.URL.Query().Get("path")
	if filePath == "" {
		http.Error(w, "Missing 'path' parameter", http.StatusBadRequest)
		return
	}

	// Security check: ensure path exists and is accessible
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		log.Printf("[ERROR] Invalid path %s: %v", filePath, err)
		http.Error(w, "Invalid path", http.StatusBadRequest)
		return
	}

	// Check file size before reading
	info, err := os.Stat(absPath)
	if err != nil {
		log.Printf("[ERROR] Failed to stat file %s: %v", absPath, err)
		http.Error(w, fmt.Sprintf("File not found: %v", err), http.StatusNotFound)
		return
	}

	if info.IsDir() {
		http.Error(w, "Path is a directory, not a file", http.StatusBadRequest)
		return
	}

	if info.Size() > maxFileSize {
		http.Error(w, fmt.Sprintf("File too large (max %d MB)", maxFileSize/(1024*1024)), http.StatusBadRequest)
		return
	}

	// Read file content
	content, err := os.ReadFile(absPath)
	if err != nil {
		log.Printf("[ERROR] Failed to read file %s: %v", absPath, err)
		http.Error(w, fmt.Sprintf("Failed to read file: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[INFO] File read: %s (%d bytes)", absPath, len(content))

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(FileReadResponse{
		Path:    absPath,
		Content: string(content),
		Size:    info.Size(),
	})
}

// writeFile writes content to a file
func writeFile(w http.ResponseWriter, r *http.Request) {
	var req FileWriteRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.Path == "" {
		http.Error(w, "Missing 'path' field", http.StatusBadRequest)
		return
	}

	// Security check: ensure path is valid
	absPath, err := filepath.Abs(req.Path)
	if err != nil {
		log.Printf("[ERROR] Invalid path %s: %v", req.Path, err)
		http.Error(w, "Invalid path", http.StatusBadRequest)
		return
	}

	// Check content size
	if len(req.Content) > maxFileSize {
		http.Error(w, fmt.Sprintf("Content too large (max %d MB)", maxFileSize/(1024*1024)), http.StatusBadRequest)
		return
	}

	// Check if file exists and get permissions
	existingInfo, err := os.Stat(absPath)
	fileMode := os.FileMode(0644)
	if err == nil {
		// File exists, preserve permissions
		fileMode = existingInfo.Mode()
	}

	// Create directory if it doesn't exist
	dir := filepath.Dir(absPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		log.Printf("[ERROR] Failed to create directory %s: %v", dir, err)
		http.Error(w, fmt.Sprintf("Failed to create directory: %v", err), http.StatusInternalServerError)
		return
	}

	// Write file
	if err := os.WriteFile(absPath, []byte(req.Content), fileMode); err != nil {
		log.Printf("[ERROR] Failed to write file %s: %v", absPath, err)
		http.Error(w, fmt.Sprintf("Failed to write file: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[INFO] File written: %s (%d bytes)", absPath, len(req.Content))

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "success",
		"message": "File written successfully",
		"path":    absPath,
		"size":    len(req.Content),
	})
}

// DeleteFile handles file deletion
func DeleteFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete && r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	filePath := r.URL.Query().Get("path")
	if filePath == "" {
		http.Error(w, "Missing 'path' parameter", http.StatusBadRequest)
		return
	}

	absPath, err := filepath.Abs(filePath)
	if err != nil {
		http.Error(w, "Invalid path", http.StatusBadRequest)
		return
	}

	// Check if file exists
	if _, err := os.Stat(absPath); os.IsNotExist(err) {
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	// Delete file
	if err := os.Remove(absPath); err != nil {
		log.Printf("[ERROR] Failed to delete file %s: %v", absPath, err)
		http.Error(w, fmt.Sprintf("Failed to delete file: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[INFO] File deleted: %s", absPath)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "success",
		"message": "File deleted successfully",
		"path":    absPath,
	})
}

// UploadFile handles file uploads
func UploadFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse multipart form (max 10MB)
	if err := r.ParseMultipartForm(maxFileSize); err != nil {
		http.Error(w, "File too large or invalid form", http.StatusBadRequest)
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Failed to read file from form", http.StatusBadRequest)
		return
	}
	defer file.Close()

	destPath := r.FormValue("path")
	if destPath == "" {
		destPath = "./" + header.Filename
	}

	absPath, err := filepath.Abs(destPath)
	if err != nil {
		http.Error(w, "Invalid destination path", http.StatusBadRequest)
		return
	}

	// Create destination file
	dst, err := os.Create(absPath)
	if err != nil {
		log.Printf("[ERROR] Failed to create file %s: %v", absPath, err)
		http.Error(w, fmt.Sprintf("Failed to create file: %v", err), http.StatusInternalServerError)
		return
	}
	defer dst.Close()

	// Copy file content
	written, err := io.Copy(dst, file)
	if err != nil {
		log.Printf("[ERROR] Failed to write file %s: %v", absPath, err)
		http.Error(w, fmt.Sprintf("Failed to write file: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[INFO] File uploaded: %s (%d bytes)", absPath, written)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "success",
		"message": "File uploaded successfully",
		"path":    absPath,
		"size":    written,
	})
}

// Made with Bob
