"""Tests for bird classification model."""

import tempfile
from pathlib import Path

import pytest
import torch

from src.models.bird_classifier import BirdClassifier, ModelConfig
from src.models.model_registry import ModelRegistry, ModelStage


class TestModelConfig:
    def test_default_config(self):
        config = ModelConfig()
        assert config.backbone == "efficientnet_b4"
        assert config.num_classes == 525
        assert config.pretrained is True
        assert config.image_size == 380

    def test_from_dict(self):
        d = {
            "model": {
                "backbone": "resnet50",
                "num_classes": 100,
                "input": {"image_size": 224},
                "head": {"type": "mlp", "hidden_dim": 256},
            }
        }
        config = ModelConfig.from_dict(d)
        assert config.backbone == "resnet50"
        assert config.num_classes == 100
        assert config.image_size == 224
        assert config.head_type == "mlp"
        assert config.head_hidden_dim == 256


class TestBirdClassifier:
    @pytest.fixture
    def small_model(self):
        """Create a small model for testing."""
        config = ModelConfig(
            backbone="efficientnet_b0",
            num_classes=10,
            pretrained=False,
            image_size=64,
        )
        return BirdClassifier(config)

    def test_forward_shape(self, small_model):
        x = torch.randn(2, 3, 64, 64)
        output = small_model(x)
        assert output.shape == (2, 10)

    def test_predict(self, small_model):
        x = torch.randn(1, 3, 64, 64)
        result = small_model.predict(x, top_k=3)
        assert "probabilities" in result
        assert "class_indices" in result
        assert result["probabilities"].shape == (1, 3)
        assert result["class_indices"].shape == (1, 3)

    def test_predict_with_class_names(self, small_model):
        names = [f"species_{i}" for i in range(10)]
        small_model.class_names = names
        x = torch.randn(1, 3, 64, 64)
        result = small_model.predict(x, top_k=3)
        assert "class_names" in result
        assert len(result["class_names"][0]) == 3

    def test_class_names_validation(self, small_model):
        with pytest.raises(ValueError, match="Expected 10"):
            small_model.class_names = ["a", "b"]

    def test_get_embeddings(self, small_model):
        x = torch.randn(2, 3, 64, 64)
        embeddings = small_model.get_embeddings(x)
        assert embeddings.shape[0] == 2
        assert embeddings.dim() == 2

    def test_save_and_load(self, small_model):
        small_model.class_names = [f"species_{i}" for i in range(10)]

        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "model.pt"
            small_model.save(path)

            loaded = BirdClassifier.load(path)
            assert loaded.config.num_classes == 10
            assert loaded.config.backbone == "efficientnet_b0"
            assert loaded.class_names == small_model.class_names

            # Verify outputs match
            x = torch.randn(1, 3, 64, 64)
            small_model.eval()
            loaded.eval()
            with torch.no_grad():
                orig_out = small_model(x)
                loaded_out = loaded(x)
            assert torch.allclose(orig_out, loaded_out, atol=1e-5)

    def test_count_parameters(self, small_model):
        params = small_model.count_parameters()
        assert params["total"] > 0
        assert params["trainable"] > 0
        assert params["frozen"] == 0

    def test_freeze_backbone(self, small_model):
        small_model.freeze_backbone()
        params = small_model.count_parameters()
        assert params["frozen"] > 0
        assert params["trainable"] < params["total"]

    def test_unfreeze_backbone(self, small_model):
        small_model.freeze_backbone()
        small_model.unfreeze_backbone()
        params = small_model.count_parameters()
        assert params["frozen"] == 0


class TestModelRegistry:
    @pytest.fixture
    def registry(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            yield ModelRegistry(tmpdir)

    @pytest.fixture
    def model_file(self):
        with tempfile.NamedTemporaryFile(suffix=".pt", delete=False) as f:
            torch.save({"dummy": True}, f.name)
            yield f.name

    def test_register_model(self, registry, model_file):
        version = registry.register_model(
            name="test-model",
            model_path=model_file,
            metrics={"accuracy": 0.95},
        )
        assert version.version == "v1"
        assert version.metrics["accuracy"] == 0.95

    def test_auto_increment_version(self, registry, model_file):
        registry.register_model(name="test-model", model_path=model_file)
        v2 = registry.register_model(name="test-model", model_path=model_file)
        assert v2.version == "v2"

    def test_get_model(self, registry, model_file):
        registry.register_model(name="test-model", model_path=model_file)
        result = registry.get_model("test-model")
        assert result is not None
        assert result.version == "v1"

    def test_get_nonexistent(self, registry):
        assert registry.get_model("nonexistent") is None

    def test_promote_model(self, registry, model_file):
        registry.register_model(name="test-model", model_path=model_file)
        promoted = registry.promote_model("test-model", "v1", ModelStage.PRODUCTION)
        assert promoted.stage == ModelStage.PRODUCTION

    def test_promote_archives_previous(self, registry, model_file):
        registry.register_model(name="test-model", model_path=model_file)
        registry.promote_model("test-model", "v1", ModelStage.PRODUCTION)

        registry.register_model(name="test-model", model_path=model_file)
        registry.promote_model("test-model", "v2", ModelStage.PRODUCTION)

        v1 = registry.get_model("test-model", version="v1")
        assert v1.stage == ModelStage.ARCHIVED

    def test_get_production_model(self, registry, model_file):
        registry.register_model(name="test-model", model_path=model_file)
        registry.promote_model("test-model", "v1", ModelStage.PRODUCTION)
        prod = registry.get_production_model("test-model")
        assert prod is not None
        assert prod.stage == ModelStage.PRODUCTION

    def test_list_models(self, registry, model_file):
        registry.register_model(name="model-a", model_path=model_file)
        registry.register_model(name="model-b", model_path=model_file)
        models = registry.list_models()
        assert "model-a" in models
        assert "model-b" in models
