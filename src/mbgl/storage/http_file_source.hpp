#ifndef MBGL_STORAGE_HTTP_FILE_SOURCE
#define MBGL_STORAGE_HTTP_FILE_SOURCE

#include <mbgl/storage/file_source.hpp>

namespace mbgl {

class HTTPFileSource : public FileSource {
public:
    HTTPFileSource();
    ~HTTPFileSource() override;

    std::unique_ptr<AsyncRequest> request(const Resource&, Callback) override;

    static uint32_t maximumConcurrentRequests();

private:
    friend class HTTPRequest;
    class Impl;
    std::unique_ptr<Impl> impl;
};

} // namespace mbgl

#endif // MBGL_STORAGE_HTTP_FILE_SOURCE
