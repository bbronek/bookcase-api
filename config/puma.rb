threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)
http_content_length_limit 10 * 1024 * 1024

plugin :tmp_restart
raise_exception_on_sigterm false
