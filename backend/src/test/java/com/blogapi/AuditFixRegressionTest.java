package com.blogapi;

import com.blogapi.entity.Comment;
import com.blogapi.entity.Post;
import com.blogapi.entity.User;
import com.blogapi.repository.CommentRepository;
import com.blogapi.repository.PostRepository;
import com.blogapi.repository.UserRepository;
import com.blogapi.security.JwtService;
import com.blogapi.security.UserDetailsServiceImpl;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.MockMvcPrint;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc(print = MockMvcPrint.NONE)
@Transactional
@TestPropertySource(properties = {
        "spring.datasource.url=jdbc:h2:mem:auditfix;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "spring.datasource.username=sa", "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.jpa.hibernate.ddl-auto=create-drop", "spring.jpa.show-sql=false",
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "app.jwt.secret=cmVjb3JkLWFwaS10ZXN0LXNpZ25pbmcta2V5LWF0LWxlYXN0LTMyLWJ5dGVzLWxvbmc=",
        "logging.level.org.hibernate.SQL=OFF"
})
class AuditFixRegressionTest {
    @Autowired MockMvc http;
    @Autowired ObjectMapper json;
    @Autowired UserRepository users;
    @Autowired PostRepository posts;
    @Autowired CommentRepository comments;
    @Autowired JwtService jwt;
    @Autowired UserDetailsServiceImpl details;
    User owner;
    String token;

    @BeforeEach
    void actor() {
        String name = "fix-" + UUID.randomUUID();
        owner = users.save(User.builder().username(name).email(name + "@example.test")
                .password("unused-jwt-fixture").enabled(true).build());
        token = jwt.generateAccessToken(details.loadUserByUsername(name));
    }

    @ParameterizedTest
    @ValueSource(strings = {"page=-1", "size=0", "size=-1"})
    void invalidCommentPaginationIsClientError(String query) throws Exception {
        Post p = fixture();
        http.perform(get("/api/v1/posts/" + p.getId() + "/comments?" + query))
                .andExpect(status().isBadRequest());
        http.perform(get("/api/v1/posts/" + p.getId() + "/comments?page=0&size=1"))
                .andExpect(status().isOk());
    }

    @Test
    void crossPostParentIsRejectedWithoutCreatingCommentButValidReplyStillWorks() throws Exception {
        Post first = fixture(), second = fixture();
        Comment parent = comments.save(Comment.builder().post(first).author(owner)
                .content("parent").build());
        long before = comments.count();
        String body = json.writeValueAsString(Map.of("content", "reply", "parentId", parent.getId()));
        http.perform(post("/api/v1/posts/" + second.getId() + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest());
        assertThat(comments.count()).isEqualTo(before);
        http.perform(post("/api/v1/posts/" + first.getId() + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.depth").value(1));
    }

    @Test
    void depthLimitIsClientError() throws Exception {
        Post p = fixture();
        Comment parent = null;
        for (int depth = 0; depth <= 5; depth++) {
            parent = comments.save(Comment.builder().post(p).author(owner).parent(parent)
                    .depth(depth).content("parent").build());
        }
        long before = comments.count();
        http.perform(post("/api/v1/posts/" + p.getId() + "/comments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("content", "too deep", "parentId", parent.getId()))))
                .andExpect(status().isBadRequest());
        assertThat(comments.count()).isEqualTo(before);
    }

    @ParameterizedTest
    @ValueSource(ints = {200, 201, 220, 255})
    void longDuplicateTitlesFitSchemaAndKeepUrlOnUnchangedUpdate(int length) throws Exception {
        String title = "a".repeat(length);
        JsonNode first = create(title), second = create(title);
        assertThat(first.get("slug").asText()).hasSizeLessThanOrEqualTo(Post.MAX_SLUG_LENGTH);
        assertThat(second.get("slug").asText()).hasSizeLessThanOrEqualTo(Post.MAX_SLUG_LENGTH)
                .isNotEqualTo(first.get("slug").asText());
        posts.flush(); // Exercise the real test database's varchar constraint, not just response mapping.
        http.perform(put("/api/v1/posts/" + first.get("id").asLong())
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("title", title))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.slug").value(first.get("slug").asText()));
        http.perform(put("/api/v1/posts/" + first.get("id").asLong())
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("title", "b".repeat(255)))))
                .andExpect(status().isOk());
        posts.flush();
        assertThat(posts.findById(first.get("id").asLong()).orElseThrow().getSlug())
                .hasSizeLessThanOrEqualTo(Post.MAX_SLUG_LENGTH);
    }

    @Test
    void existingShortSlugBehaviorAndNonAsciiFallbackStayUsable() throws Exception {
        assertThat(create("Normal existing title").get("slug").asText()).isEqualTo("normal-existing-title");
        JsonNode first = create("漢字"), second = create("漢字");
        assertThat(first.get("slug").asText()).isEqualTo("post");
        assertThat(second.get("slug").asText()).isEqualTo("post-1");
    }

    @Test
    void registrationUsernamePolicyAlsoAppliesWithoutBlockingWaf() throws Exception {
        http.perform(post("/api/v1/auth/register?audit=1").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("username", "bad space",
                                "email", "bad-space@example.test", "password", "test-fixture-password"))))
                .andExpect(status().isBadRequest());
    }

    private JsonNode create(String title) throws Exception {
        String body = http.perform(post("/api/v1/posts").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("title", title, "content", "audit fixture"))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        return json.readTree(body);
    }

    private Post fixture() {
        return posts.save(Post.builder().author(owner).status(Post.Status.PUBLISHED)
                .title("fixture").slug(UUID.randomUUID().toString()).content("fixture").build());
    }
}
